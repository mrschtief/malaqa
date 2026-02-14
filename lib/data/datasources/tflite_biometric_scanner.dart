import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/image_converter.dart';
import '../../domain/entities/face_vector.dart';
import '../../domain/interfaces/biometric_scanner.dart';

class TfliteBiometricScanner
    implements BiometricScanner<BiometricScanRequest<CameraImage>> {
  TfliteBiometricScanner();

  static const _modelAssetPath = 'assets/models/mobilefacenet.tflite';

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
      return const <FaceVector>[];
    }

    final converted = ImageConverter.cameraImageToImage(
      image: input.image,
      rotationDegrees: input.rotationDegrees,
    );
    if (converted == null) {
      return const <FaceVector>[];
    }

    final interpreter = await _ensureInterpreter();
    final outputTensorShape = interpreter.getOutputTensors().first.shape;
    final vectors = <FaceVector>[];

    for (final bounds in allFaces) {
      final faceImage = ImageConverter.cropFace(
        image: converted,
        faceBounds: bounds,
      );
      if (faceImage == null) {
        continue;
      }

      final preProcessed = ImageConverter.preProcessFace(faceImage);
      final modelInput = _toModelInput(preProcessed);
      final outputBuffer = _createZeroTensor(outputTensorShape);

      interpreter.run(modelInput, outputBuffer);
      final embedding = _flattenOutput(outputBuffer);
      if (embedding.isEmpty) {
        continue;
      }
      vectors.add(FaceVector(embedding));
    }

    return vectors;
  }

  Future<Interpreter> _ensureInterpreter() async {
    if (_interpreter != null) {
      return _interpreter!;
    }
    _interpreterLoading ??= _loadInterpreter();
    _interpreter = await _interpreterLoading!;
    return _interpreter!;
  }

  Future<Interpreter> _loadInterpreter() async {
    final options = InterpreterOptions()..threads = 4;
    if (Platform.isAndroid) {
      options.useNnApiForAndroid = true;
    }
    return Interpreter.fromAsset(_modelAssetPath, options: options);
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
