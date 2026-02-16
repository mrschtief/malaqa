import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/image_converter.dart';
import '../../domain/entities/face_vector.dart';
import '../../domain/interfaces/biometric_scanner.dart';

class TfliteBiometricScanner
    implements BiometricScanner<BiometricScanRequest<CameraImage>> {
  TfliteBiometricScanner();

  static const _modelAssetPath = 'assets/models/mobilefacenet.tflite';
  static const int _fallbackEmbeddingLength = 192;

  Interpreter? _interpreter;
  Future<Interpreter>? _interpreterLoading;

  @override
  Future<FaceVector?> captureFace(
      BiometricScanRequest<CameraImage> input) async {
    final bounds = input.faceBounds;
    if (bounds == null) {
      return null;
    }

    final vectors = await scanFaces(input, [bounds]);
    if (vectors.isEmpty) {
      return null;
    }
    return vectors.first;
  }

  @override
  Future<List<FaceVector>> scanFaces(
    BiometricScanRequest<CameraImage> input,
    List<FaceBounds> allFaces,
  ) async {
    if (allFaces.isEmpty) {
      AppLogger.throttled(
        'SCANNER.scanFaces.noFaces',
        const Duration(seconds: 2),
        () => AppLogger.debug('SCANNER', 'scanFaces(): no faces provided'),
      );
      return const <FaceVector>[];
    }

    final converted = ImageConverter.cameraImageToImage(
      image: input.image,
      rotationDegrees: input.rotationDegrees,
    );
    if (converted == null) {
      AppLogger.throttled(
        'SCANNER.scanFaces.convertedNull',
        const Duration(seconds: 2),
        () => AppLogger.warn(
          'SCANNER',
          'scanFaces(): image conversion returned null '
              '(formatGroup=${input.image.format.group}, '
              'raw=${input.image.format.raw}, '
              'size=${input.image.width}x${input.image.height}, '
              'planes=${input.image.planes.length}, '
              'rotation=${input.rotationDegrees})',
        ),
      );
      return const <FaceVector>[];
    }

    final interpreter = await _ensureInterpreter();
    final outputTensorShape = _resolveOutputTensorShape(interpreter);
    final fallbackLength = _embeddingLengthFromShape(outputTensorShape);
    final vectors = <FaceVector>[];

    for (final bounds in allFaces) {
      final faceImage = ImageConverter.cropFace(
        image: converted,
        faceBounds: bounds,
      );
      if (faceImage == null) {
        AppLogger.throttled(
          'SCANNER.cropFace.null',
          const Duration(seconds: 2),
          () => AppLogger.warn(
            'SCANNER',
            'cropFace() returned null (bounds='
                'l=${bounds.left.toStringAsFixed(1)} '
                't=${bounds.top.toStringAsFixed(1)} '
                'r=${bounds.right.toStringAsFixed(1)} '
                'b=${bounds.bottom.toStringAsFixed(1)} '
                '| img=${converted.width}x${converted.height})',
          ),
        );
        continue;
      }

      try {
        final preProcessed = ImageConverter.preProcessFace(faceImage);
        final modelInput = _toModelInput(preProcessed);
        if (interpreter == null) {
          vectors.add(_dummyVector(fallbackLength));
          continue;
        }
        final outputBuffer = _createZeroTensor(outputTensorShape);
        interpreter.run(modelInput, outputBuffer);
        final embedding = _flattenOutput(outputBuffer);
        if (embedding.isEmpty) {
          vectors.add(_dummyVector(fallbackLength));
          continue;
        }
        vectors.add(FaceVector(embedding));
      } catch (error, stackTrace) {
        _logNativeCrashGuard(error, stackTrace);
        vectors.add(_dummyVector(fallbackLength));
      }
    }

    return vectors;
  }

  Future<Interpreter?> _ensureInterpreter() async {
    if (_interpreter != null) {
      return _interpreter!;
    }
    _interpreterLoading ??= _loadInterpreter();
    try {
      _interpreter = await _interpreterLoading!;
    } catch (error, stackTrace) {
      _interpreterLoading = null;
      _logNativeCrashGuard(error, stackTrace);
      return null;
    }
    return _interpreter!;
  }

  Future<Interpreter> _loadInterpreter() async {
    AppLogger.info(
        'SCANNER', 'Loading TFLite interpreter from asset=$_modelAssetPath');
    final options = InterpreterOptions()..threads = 4;
    if (Platform.isAndroid) {
      options.useNnApiForAndroid = true;
    }
    final interpreter = await Interpreter.fromAsset(
      _modelAssetPath,
      options: options,
    );
    try {
      final in0 = interpreter.getInputTensors().first;
      final out0 = interpreter.getOutputTensors().first;
      AppLogger.info(
        'SCANNER',
        'TFLite interpreter ready. inputShape=${in0.shape} outputShape=${out0.shape}',
      );
    } catch (_) {
      // Ignore shape introspection errors; not critical.
    }
    return interpreter;
  }

  bool _isNativeTfLiteLoadError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('libtensorflowlite_jni.so') ||
        message.contains('tensorflowlite_jni') ||
        message.contains('dlopen failed') ||
        message.contains('couldn\'t find "libtensorflowlite_jni.so"') ||
        message.contains('signal 11') ||
        message.contains('segmentation fault');
  }

  void _logNativeCrashGuard(Object error, StackTrace stackTrace) {
    final prefix = _isNativeTfLiteLoadError(error) ? 'Native ' : '';
    AppLogger.error(
      'SCANNER',
      '[CRITICAL] ${prefix}TFLite Crash prevented. Returning Dummy Vector.',
      error: error,
      stackTrace: stackTrace,
    );
  }

  List<int> _resolveOutputTensorShape(Interpreter? interpreter) {
    if (interpreter == null) {
      return const <int>[1, _fallbackEmbeddingLength];
    }
    try {
      final shape = interpreter.getOutputTensors().first.shape;
      if (shape.isEmpty) {
        return const <int>[1, _fallbackEmbeddingLength];
      }
      return shape;
    } catch (error, stackTrace) {
      _logNativeCrashGuard(error, stackTrace);
      return const <int>[1, _fallbackEmbeddingLength];
    }
  }

  int _embeddingLengthFromShape(List<int> shape) {
    if (shape.isEmpty) {
      return _fallbackEmbeddingLength;
    }
    final last = shape.last;
    if (last <= 0) {
      return _fallbackEmbeddingLength;
    }
    return last;
  }

  FaceVector _dummyVector(int length) {
    return FaceVector(List<double>.filled(length, 0.0, growable: false));
  }

  List<List<List<List<double>>>> _toModelInput(Float32List preProcessed) {
    if (preProcessed.length != 112 * 112 * 3) {
      throw ArgumentError.value(
        preProcessed.length,
        'preProcessed',
        'Expected 112x112x3 float input.',
      );
    }

    var index = 0;
    final imageTensor = List.generate(
      112,
      (_) => List.generate(
        112,
        (_) => List.generate(
          3,
          (_) => preProcessed[index++],
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );

    return [imageTensor];
  }

  Object _createZeroTensor(List<int> shape, [int depth = 0]) {
    if (shape.isEmpty) {
      throw ArgumentError.value(
          shape, 'shape', 'Tensor shape cannot be empty.');
    }
    if (depth == shape.length - 1) {
      return List<double>.filled(shape[depth], 0.0, growable: false);
    }
    return List.generate(
      shape[depth],
      (_) => _createZeroTensor(shape, depth + 1),
      growable: false,
    );
  }

  List<double> _flattenOutput(Object output) {
    final values = <double>[];

    void collect(Object node) {
      if (node is List) {
        for (final child in node) {
          collect(child);
        }
        return;
      }
      if (node is num) {
        values.add(node.toDouble());
      }
    }

    collect(output);
    return values;
  }
}
