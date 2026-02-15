import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/interfaces/biometric_scanner.dart';
import '../../domain/repositories/chain_repository.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/meeting/meeting_cubit.dart';
import '../blocs/proximity/proximity_cubit.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'qr_scan_page.dart';
import '../widgets/proximity/proximity_notification.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  static const Duration _scannerHeartbeatInterval = Duration(seconds: 1);
  static const Duration _streamRecoveryDelay = Duration(milliseconds: 350);
  static const Map<DeviceOrientation, int> _orientations =
      <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _cameraController;
  late final FaceDetector _faceDetector;
  late final AnimationController _reticlePulseController;
  late final AppSettingsService _appSettings;

  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  bool _isCreatingIdentity = false;

  CameraImage? _latestFrame;
  List<Rect> _latestFaceBoxes = const <Rect>[];
  Size? _latestImageSize;
  int _latestImageRotationDegrees = 0;
  String _cameraStatus = 'Starting camera...';
  DateTime? _lastWarmupFailureAt;
  DateTime? _lastConverterErrorAt;
  DateTime? _lastDetectorClosedLogAt;
  bool _isFaceDetectorWarmedUp = false;
  bool _isFaceDetectorClosed = false;
  bool _isRecoveringImageStream = false;
  bool _isDisposing = false;
  String? _lastCameraErrorDescription;

  @override
  void initState() {
    super.initState();
    _reticlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _appSettings = getIt<AppSettingsService>()
      ..addListener(_handleAppSettingsChanged);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableClassification: true,
      ),
    );
    AppLogger.log(
      'SCANNER',
      'FaceDetector created (mode=fast, classification=true).',
    );
    _initializeCamera();
    unawaited(context.read<AuthCubit>().checkIdentity());
  }

  Future<void> _initializeCamera() async {
    CameraController? initializedController;
    try {
      final permission = await Permission.camera.request();
      AppLogger.log('SCANNER', 'Camera permission status: $permission');
      if (!permission.isGranted) {
        AppLogger.error('SCANNER', 'Camera permission denied.');
        if (!mounted) {
          return;
        }
        setState(() {
          _cameraStatus = 'Camera permission denied';
        });
        return;
      }

      final cameras = await availableCameras();
      AppLogger.log('SCANNER', 'availableCameras() -> ${cameras.length}');
      if (cameras.isEmpty) {
        AppLogger.error('SCANNER', 'No camera available on device.');
        if (!mounted) {
          return;
        }
        setState(() {
          _cameraStatus = 'No camera available';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      AppLogger.log(
        'SCANNER',
        'Selected camera: lens=${selectedCamera.lensDirection} '
            'sensorOrientation=${selectedCamera.sensorOrientation}',
      );

      initializedController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      _cameraController = initializedController;
      initializedController.addListener(_logCameraControllerWarnings);

      await initializedController.initialize();
      AppLogger.log(
        'SCANNER',
        'Camera initialized. preview=${initializedController.value.previewSize}',
      );
      AppLogger.log(
        'SCANNER',
        'Requested imageFormatGroup='
            '${Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21}',
      );
      await initializedController.startImageStream(_processCameraFrame);
      AppLogger.log(
        'SCANNER',
        'Image stream started. Watch native logcat for CameraX '
            'HardwareBuffer/Surface warnings.',
      );

      if (!mounted) {
        initializedController.removeListener(_logCameraControllerWarnings);
        await initializedController.dispose();
        _cameraController = null;
        return;
      }

      setState(() {
        _isCameraReady = true;
        _cameraStatus = 'Looking for you...';
      });
    } on CameraException catch (error, stackTrace) {
      if (initializedController != null) {
        initializedController.removeListener(_logCameraControllerWarnings);
        if (initializedController.value.isStreamingImages) {
          await initializedController.stopImageStream();
        }
        await initializedController.dispose();
      }
      AppLogger.error(
        'SCANNER',
        'Camera initialization failed '
            '(code=${error.code}, description=${error.description})',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        _cameraController = null;
        return;
      }
      setState(() {
        _cameraStatus = 'Camera init failed: ${error.code}';
        _cameraController = null;
      });
    } catch (error, stackTrace) {
      if (initializedController != null) {
        initializedController.removeListener(_logCameraControllerWarnings);
        if (initializedController.value.isStreamingImages) {
          await initializedController.stopImageStream();
        }
        await initializedController.dispose();
      }
      AppLogger.error(
        'SCANNER',
        'Unexpected camera initialization failure',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        _cameraController = null;
        return;
      }
      setState(() {
        _cameraStatus = 'Camera init failed';
        _cameraController = null;
      });
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame ||
        _isRecoveringImageStream ||
        _isDisposing ||
        !mounted ||
        _isFaceDetectorClosed) {
      if (_isFaceDetectorClosed) {
        _logFaceDetectorClosedSkip();
      }
      return;
    }

    _latestFrame = image;
    _latestImageSize = Size(image.width.toDouble(), image.height.toDouble());
    _isProcessingFrame = true;

    try {
      final rotationDegrees = _resolvedRotationDegrees();
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        return;
      }

      final detectedFaces = await _detectFacesWithWarmup(inputImage);

      final sortedFaces = [...detectedFaces]..sort(
          (a, b) => (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height),
        );
      final sortedBoxes = sortedFaces.map((face) => face.boundingBox).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _latestFaceBoxes = List<Rect>.unmodifiable(sortedBoxes);
        _latestImageRotationDegrees = rotationDegrees ?? 0;
      });

      final state = context.read<AuthCubit>().state;
      if (state is AuthScanning && sortedBoxes.isNotEmpty) {
        final request = _scanRequest(image);
        final bounds = sortedFaces
            .take(2)
            .map(_faceBoundsFromFace)
            .toList(growable: false);
        unawaited(context.read<AuthCubit>().processFrame(request, bounds));
      }
      if (state is AuthAuthenticated && sortedBoxes.isNotEmpty) {
        final request = _scanRequest(image);
        final bounds =
            sortedFaces.map(_faceBoundsFromFace).toList(growable: false);
        unawaited(context.read<MeetingCubit>().processFrame(request, bounds));
      }
    } on PlatformException catch (error, stackTrace) {
      final isConverterError = error.code == 'InputImageConverterError' ||
          (error.message?.contains('ImageFormat is not supported') ?? false);
      if (isConverterError) {
        final now = DateTime.now();
        if (_lastConverterErrorAt == null ||
            now.difference(_lastConverterErrorAt!) >=
                _scannerHeartbeatInterval) {
          _lastConverterErrorAt = now;
          AppLogger.error(
            'SCANNER',
            'InputImage conversion failed on stream frame. '
                '${_cameraImageDebugInfo(image)}',
            error: error,
            stackTrace: stackTrace,
          );
        }
        unawaited(
          _recoverFromInputImageConverterError(
            reason: '${error.code}: ${error.message}',
          ),
        );
        return;
      }
      AppLogger.error(
        'SCANNER',
        'PlatformException while processing frame',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'SCANNER',
        'Frame processing failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    if (_cameraController == null) {
      return null;
    }

    final rotation = _resolvedInputImageRotation();
    if (rotation == null) {
      return null;
    }

    final rawFormat = image.format.raw;
    if (rawFormat is! int) {
      return null;
    }
    final format = InputImageFormatValue.fromRawValue(rawFormat);
    if (format == null) {
      return null;
    }

    if (Platform.isIOS) {
      if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
        return null;
      }
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    if (!Platform.isAndroid) {
      return null;
    }

    if (format == InputImageFormat.nv21 ||
        image.format.group == ImageFormatGroup.nv21 ||
        format == InputImageFormat.yv12) {
      if (image.planes.isEmpty) {
        return null;
      }
      final plane = image.planes.first;
      if (plane.bytes.isEmpty) {
        return null;
      }
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format == InputImageFormat.yv12
              ? InputImageFormat.yv12
              : InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    if (format == InputImageFormat.yuv_420_888 ||
        image.format.group == ImageFormatGroup.yuv420) {
      final nv21Bytes = _convertYuv420ToNv21(image);
      if (nv21Bytes == null || nv21Bytes.isEmpty) {
        return null;
      }
      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    return null;
  }

  InputImageRotation? _resolvedInputImageRotation() {
    final controller = _cameraController;
    if (controller == null) {
      return null;
    }
    final sensorOrientation = controller.description.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (!Platform.isAndroid) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    var rotationCompensation =
        _orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) {
      return null;
    }
    if (controller.description.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  int? _resolvedRotationDegrees() {
    return _resolvedInputImageRotation()?.rawValue;
  }

  Uint8List? _convertYuv420ToNv21(CameraImage image) {
    if (image.planes.length < 3) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final output = Uint8List(width * height + 2 * uvWidth * uvHeight);

    var offset = 0;
    for (var row = 0; row < height; row++) {
      final rowOffset = row * yPlane.bytesPerRow;
      for (var col = 0; col < width; col++) {
        final index = rowOffset + col * yPixelStride;
        if (index >= yPlane.bytes.length) {
          return null;
        }
        output[offset++] = yPlane.bytes[index];
      }
    }

    for (var row = 0; row < uvHeight; row++) {
      final uRowOffset = row * uPlane.bytesPerRow;
      final vRowOffset = row * vPlane.bytesPerRow;
      for (var col = 0; col < uvWidth; col++) {
        final vIndex = vRowOffset + col * vPixelStride;
        final uIndex = uRowOffset + col * uPixelStride;
        if (vIndex >= vPlane.bytes.length || uIndex >= uPlane.bytes.length) {
          return null;
        }
        output[offset++] = vPlane.bytes[vIndex];
        output[offset++] = uPlane.bytes[uIndex];
      }
    }
    return output;
  }

  String _cameraImageDebugInfo(CameraImage image) {
    final buffer = StringBuffer()
      ..write(
        'formatGroup=${image.format.group} rawFormat=${image.format.raw} '
        'size=${image.width}x${image.height} planes=${image.planes.length}',
      );
    for (var i = 0; i < image.planes.length; i++) {
      final plane = image.planes[i];
      buffer.write(
        ' p$i(bytes=${plane.bytes.length}, rowStride=${plane.bytesPerRow}, '
        'pixelStride=${plane.bytesPerPixel})',
      );
    }
    return buffer.toString();
  }

  Future<void> _recoverFromInputImageConverterError({
    required String reason,
  }) async {
    if (_isRecoveringImageStream) {
      return;
    }
    final controller = _cameraController;
    if (controller == null) {
      return;
    }

    _isRecoveringImageStream = true;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      AppLogger.log(
        'SCANNER',
        'Image stream paused after converter error: $reason',
      );
      await Future<void>.delayed(_streamRecoveryDelay);
      if (!mounted ||
          _isDisposing ||
          _cameraController != controller ||
          _isFaceDetectorClosed) {
        return;
      }
      await controller.startImageStream(_processCameraFrame);
      AppLogger.log('SCANNER', 'Image stream resumed after converter recovery');
    } catch (error, stackTrace) {
      AppLogger.error(
        'SCANNER',
        'Failed to recover camera stream after converter error',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isRecoveringImageStream = false;
    }
  }

  Future<List<Face>> _detectFacesWithWarmup(InputImage image) async {
    if (_isFaceDetectorClosed) {
      _logFaceDetectorClosedSkip();
      return const <Face>[];
    }
    if (_isFaceDetectorWarmedUp) {
      return _faceDetector.processImage(image);
    }

    try {
      final faces = await _faceDetector.processImage(image);
      _isFaceDetectorWarmedUp = true;
      AppLogger.log(
        'SCANNER',
        'FaceDetector warm-up successful. Initial rawFaces=${faces.length}.',
      );
      return faces;
    } catch (error, stackTrace) {
      final now = DateTime.now();
      if (_lastWarmupFailureAt == null ||
          now.difference(_lastWarmupFailureAt!) >= _scannerHeartbeatInterval) {
        _lastWarmupFailureAt = now;
        AppLogger.error(
          'SCANNER',
          'FaceDetector warm-up failed. '
              'Check model download / Google Play Services.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  void _logFaceDetectorClosedSkip() {
    final now = DateTime.now();
    if (_lastDetectorClosedLogAt != null &&
        now.difference(_lastDetectorClosedLogAt!) < _scannerHeartbeatInterval) {
      return;
    }
    _lastDetectorClosedLogAt = now;
    AppLogger.log('SCANNER', 'FaceDetector is closed, skipping frame.');
  }

  void _logCameraControllerWarnings() {
    final controller = _cameraController;
    if (controller == null || !controller.value.hasError) {
      return;
    }
    final description =
        controller.value.errorDescription ?? 'unknown camera controller error';
    if (_lastCameraErrorDescription == description) {
      return;
    }
    _lastCameraErrorDescription = description;
    AppLogger.error('SCANNER', 'Camera controller warning: $description');
  }

  bool _isBiometricModuleLoadingError(String errorText) {
    final normalized = errorText.toLowerCase();
    return normalized.contains('libtensorflowlite_jni.so') ||
        normalized.contains('biometrie-modul wird geladen') ||
        (normalized.contains('tensorflowlite') &&
            normalized.contains('load')) ||
        normalized.contains('dlopen failed');
  }

  bool _isDatabaseError(String errorText) {
    final normalized = errorText.toLowerCase();
    return normalized.contains('isar') ||
        normalized.contains('database') ||
        normalized.contains('db');
  }

  String _compactErrorMessage(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.length <= 120) {
      return raw;
    }
    return '${raw.substring(0, 117)}...';
  }

  Future<void> _ensureDatabaseReady() async {
    if (!getIt.isRegistered<ChainRepository>()) {
      return;
    }
    await getIt<ChainRepository>().getLatestProof();
  }

  BiometricScanRequest<CameraImage> _scanRequest(
    CameraImage image, {
    FaceBounds? faceBounds,
  }) {
    final rotationDegrees = _resolvedRotationDegrees() ??
        _cameraController!.description.sensorOrientation;
    return BiometricScanRequest<CameraImage>(
      image: image,
      faceBounds: faceBounds,
      rotationDegrees: rotationDegrees,
      isFrontCamera: _cameraController!.description.lensDirection ==
          CameraLensDirection.front,
    );
  }

  FaceBounds _faceBoundsFromFace(Face face) {
    final rect = face.boundingBox;
    return FaceBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      smilingProbability: face.smilingProbability,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
    );
  }

  FaceBounds _faceBoundsFromRect(Rect rect) {
    return FaceBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
    );
  }

  Future<void> _createIdentityFromCurrentFace() async {
    if (_isCreatingIdentity || _isDisposing) {
      return;
    }
    if (_latestFrame == null || _latestFaceBoxes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No face available yet.')),
      );
      return;
    }

    setState(() {
      _isCreatingIdentity = true;
    });

    try {
      if (_latestFaceBoxes.length == 1) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted || _isDisposing) {
        return;
      }

      final frame = _latestFrame;
      final faceBoxes = _latestFaceBoxes;
      if (frame == null || faceBoxes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gesicht im Fokus - Halten Sie kurz still...'),
          ),
        );
        return;
      }

      final scanner =
          getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>();
      var captureTimedOut = false;
      final ownerVector = await scanner
          .captureFace(
        _scanRequest(
          frame,
          faceBounds: _faceBoundsFromRect(faceBoxes.first),
        ),
      )
          .timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          captureTimedOut = true;
          return null;
        },
      );
      if (ownerVector == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              captureTimedOut
                  ? 'Stillhalten-Timeout: Gesicht im Fokus - Halten Sie kurz still...'
                  : 'Gesicht im Fokus - Halten Sie kurz still...',
            ),
          ),
        );
        return;
      }

      await _ensureDatabaseReady();
      await context.read<AuthCubit>().createIdentityFromVector(
            ownerVector: ownerVector,
          );
    } catch (error, stackTrace) {
      AppLogger.error(
        'SCANNER',
        'Owner vector capture failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      final errorText = error.toString();
      final message = _isBiometricModuleLoadingError(errorText)
          ? 'Biometrie-Modul wird geladen... bitte warten oder App neu starten.'
          : _isDatabaseError(errorText)
              ? 'DB Fehler: ${_compactErrorMessage(error)}'
              : 'Gesicht im Fokus - Halten Sie kurz still...';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingIdentity = false;
        });
      }
    }
  }

  Future<void> _syncProximityForAuth(AuthAuthenticated state) async {
    if (_appSettings.nearbyVisibility) {
      await context.read<ProximityCubit>().setAuthenticated(
            userName: state.identity.name,
            ownerVector: state.ownerVector,
          );
      return;
    }
    AppLogger.log(
      'PROXIMITY',
      'Nearby visibility disabled; discovery/advertising remains off',
    );
    await context.read<ProximityCubit>().clearAuthentication();
  }

  void _handleAppSettingsChanged() {
    if (!mounted) {
      return;
    }
    final state = context.read<AuthCubit>().state;
    if (state is! AuthAuthenticated) {
      return;
    }
    unawaited(_syncProximityForAuth(state));
  }

  @override
  void dispose() {
    _isDisposing = true;
    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      unawaited(controller.stopImageStream());
    }
    _appSettings.removeListener(_handleAppSettingsChanged);
    _reticlePulseController.dispose();
    _isFaceDetectorClosed = true;
    if (controller != null) {
      controller.removeListener(_logCameraControllerWarnings);
      controller.dispose();
    }
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
          context.read<MeetingCubit>().setAuthenticated(
                identity: state.identity,
                ownerVector: state.ownerVector,
              );
          unawaited(_syncProximityForAuth(state));
          return;
        }
        context.read<MeetingCubit>().clearAuthentication();
        unawaited(context.read<ProximityCubit>().clearAuthentication());
      },
      builder: (context, state) {
        return BlocListener<MeetingCubit, MeetingState>(
          listener: (context, meetingState) {
            if (meetingState is! MeetingSuccess) {
              return;
            }
            if (_appSettings.nearbyVisibility) {
              unawaited(
                context.read<ProximityCubit>().advertiseMeeting(
                      proof: meetingState.proof,
                      guestVector: meetingState.guestVector,
                    ),
              );
            } else {
              AppLogger.log(
                'PROXIMITY',
                'Advertising skipped because nearby visibility is disabled',
              );
            }
            showModalBottomSheet<void>(
              context: context,
              isDismissible: false,
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Begegnung #${meetingState.chainIndex}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('Chain extended! New Node created.'),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.read<MeetingCubit>().resetAfterSuccess();
                          },
                          child: const Text('Back to Scanner'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: Builder(
            builder: (context) {
              final meetingState = context.watch<MeetingCubit>().state;
              final isAuthenticated = state is AuthAuthenticated;
              final reticleColor = _reticleColorForState(state);
              final guestBounds = meetingState is MeetingReady
                  ? meetingState.guestBounds
                  : null;
              final isGuestLivenessVerified = meetingState is MeetingReady
                  ? meetingState.isLivenessVerified
                  : false;

              return Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(
                  child: !_isCameraReady || _cameraController == null
                      ? Center(
                          child: Text(
                            _cameraStatus,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_cameraController!),
                            AnimatedBuilder(
                              animation: _reticlePulseController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _ReticlePainter(
                                    faceBoxes: _latestFaceBoxes,
                                    imageSize: _latestImageSize,
                                    imageRotationDegrees:
                                        _latestImageRotationDegrees,
                                    isFrontCamera: _cameraController!
                                            .description.lensDirection ==
                                        CameraLensDirection.front,
                                    color: reticleColor,
                                    pulse: _reticlePulseController.value,
                                  ),
                                );
                              },
                            ),
                            if (_latestFaceBoxes.isNotEmpty &&
                                _latestImageSize != null)
                              CustomPaint(
                                painter: _DebugFaceOverlayPainter(
                                  faceBoxes: _latestFaceBoxes,
                                  imageSize: _latestImageSize!,
                                  imageRotationDegrees:
                                      _latestImageRotationDegrees,
                                  isFrontCamera: _cameraController!
                                          .description.lensDirection ==
                                      CameraLensDirection.front,
                                ),
                              ),
                            if (guestBounds != null && _latestImageSize != null)
                              CustomPaint(
                                painter: _GuestReticlePainter(
                                  guestBounds: guestBounds,
                                  imageSize: _latestImageSize!,
                                  imageRotationDegrees:
                                      _latestImageRotationDegrees,
                                  isFrontCamera: _cameraController!
                                          .description.lensDirection ==
                                      CameraLensDirection.front,
                                  isVerified: isGuestLivenessVerified,
                                ),
                              ),
                            if (meetingState is MeetingReady &&
                                _latestImageSize != null)
                              _GuestLivenessBadge(
                                guestBounds: meetingState.guestBounds,
                                imageSize: _latestImageSize!,
                                imageRotationDegrees:
                                    _latestImageRotationDegrees,
                                isFrontCamera: _cameraController!
                                        .description.lensDirection ==
                                    CameraLensDirection.front,
                                isVerified: meetingState.isLivenessVerified,
                                prompt: meetingState.livenessPrompt,
                              ),
                            Positioned(
                              top: 24,
                              left: 24,
                              right: 24,
                              child: _TopStatusLabel(
                                state: state,
                                meetingState: meetingState,
                              ),
                            ),
                            const Positioned(
                              top: 78,
                              left: 8,
                              right: 8,
                              child: ProximityNotificationOverlay(),
                            ),
                            if (state is AuthSetup)
                              Positioned(
                                left: 24,
                                right: 24,
                                bottom: 32,
                                child: ElevatedButton(
                                  onPressed: _isCreatingIdentity
                                      ? null
                                      : _createIdentityFromCurrentFace,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text(
                                    _isCreatingIdentity
                                        ? 'Creating Identity...'
                                        : 'Create Identity & Start Journey',
                                  ),
                                ),
                              ),
                            if (state is AuthLocked)
                              Positioned(
                                left: 24,
                                right: 24,
                                bottom: 32,
                                child: ElevatedButton(
                                  onPressed: () => context
                                      .read<AuthCubit>()
                                      .resumeScanning(),
                                  child: const Text('Retry Scan'),
                                ),
                              ),
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: !isAuthenticated,
                                child: AnimatedOpacity(
                                  opacity: isAuthenticated ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 350),
                                  child: _AuthenticatedControls(
                                    state: state,
                                    meetingState: meetingState,
                                    onCapture: () => context
                                        .read<MeetingCubit>()
                                        .captureMeeting(),
                                    onOpenMap: () => Navigator.of(context)
                                        .push(MapPage.route()),
                                    onOpenProfile: () => Navigator.of(context)
                                        .push(ProfilePage.route()),
                                    onOpenQrScan: () => Navigator.of(context)
                                        .push(QrScanPage.route()),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _reticleColorForState(AuthState state) {
    return switch (state) {
      AuthAuthenticated _ => const Color(0xFF2ECC71),
      AuthLocked _ => const Color(0xFFE74C3C),
      _ => Colors.white,
    };
  }
}

class _TopStatusLabel extends StatelessWidget {
  const _TopStatusLabel({
    required this.state,
    required this.meetingState,
  });

  final AuthState state;
  final MeetingState meetingState;

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      AuthInitial _ => 'Initializing...',
      AuthSetup s => s.message,
      AuthScanning s => s.livenessPrompt,
      AuthAuthenticated s => _meetingMessage(s),
      AuthLocked s => s.reason,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _meetingMessage(AuthAuthenticated state) {
    return switch (meetingState) {
      MeetingIdle m => 'Welcome back, ${state.identity.name}. ${m.message}',
      MeetingReady m => m.isLivenessVerified
          ? 'Guest verified. Capture is ready.'
          : 'Guest detected. ${m.livenessPrompt}',
      MeetingCapturing _ => 'Creating proof...',
      MeetingSuccess s => 'Meeting #${s.chainIndex} saved.',
      MeetingError e => e.message,
    };
  }
}

class _AuthenticatedControls extends StatelessWidget {
  const _AuthenticatedControls({
    required this.state,
    required this.meetingState,
    required this.onCapture,
    required this.onOpenMap,
    required this.onOpenProfile,
    required this.onOpenQrScan,
  });

  final AuthState state;
  final MeetingState meetingState;
  final VoidCallback onCapture;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenQrScan;

  @override
  Widget build(BuildContext context) {
    final name = state is AuthAuthenticated
        ? (state as AuthAuthenticated).identity.name
        : 'User';
    final meetingReady =
        meetingState is MeetingReady ? meetingState as MeetingReady : null;
    final isReady = meetingReady?.isLivenessVerified ?? false;
    final isCapturing = meetingState is MeetingCapturing;
    final captureLabel = isCapturing
        ? 'Capturing...'
        : isReady
            ? 'Capture Moment'
            : 'Waiting for Guest';

    return Stack(
      children: [
        Positioned(
          top: 20,
          left: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: onOpenQrScan,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              tooltip: 'Scan QR',
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(999),
              child: CircleAvatar(
                backgroundColor: Colors.black.withAlpha(180),
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: isReady
                    ? [
                        BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.45),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: ElevatedButton(
                onPressed: isReady && !isCapturing ? onCapture : null,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                ),
                child: Text(captureLabel),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 84,
          child: Center(
            child: Text(
              switch (meetingState) {
                MeetingIdle m => m.message,
                MeetingReady m => m.isLivenessVerified
                    ? 'Guest verified. Press capture.'
                    : m.livenessPrompt,
                MeetingCapturing _ => 'Creating proof...',
                MeetingSuccess _ => 'Chain extended.',
                MeetingError e => e.message,
              },
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Rect _mapImageRectToCanvas({
  required Rect imageRect,
  required Size imageSize,
  required Size canvasSize,
  required int imageRotationDegrees,
  required bool isFrontCamera,
}) {
  final normalizedRotation = ((imageRotationDegrees % 360) + 360) % 360;
  final isQuarterTurn = normalizedRotation == 90 || normalizedRotation == 270;
  final rotatedImageWidth = isQuarterTurn ? imageSize.height : imageSize.width;
  final rotatedImageHeight = isQuarterTurn ? imageSize.width : imageSize.height;
  final scaleX = canvasSize.width / rotatedImageWidth;
  final scaleY = canvasSize.height / rotatedImageHeight;
  final transformedRect = switch (normalizedRotation) {
    90 => Rect.fromLTRB(
        imageSize.height - imageRect.bottom,
        imageRect.left,
        imageSize.height - imageRect.top,
        imageRect.right,
      ),
    180 => Rect.fromLTRB(
        imageSize.width - imageRect.right,
        imageSize.height - imageRect.bottom,
        imageSize.width - imageRect.left,
        imageSize.height - imageRect.top,
      ),
    270 => Rect.fromLTRB(
        imageRect.top,
        imageSize.width - imageRect.right,
        imageRect.bottom,
        imageSize.width - imageRect.left,
      ),
    _ => imageRect,
  };

  var transformedLeft = transformedRect.left * scaleX;
  final transformedTop = transformedRect.top * scaleY;
  var transformedRight = transformedRect.right * scaleX;
  final transformedBottom = transformedRect.bottom * scaleY;

  if (isFrontCamera) {
    if (normalizedRotation == 270) {
      final mirroredLeft = canvasSize.width - transformedRight;
      final mirroredRight = canvasSize.width - transformedLeft;
      transformedLeft = mirroredLeft;
      transformedRight = mirroredRight;
    } else {
      final mirroredLeft = canvasSize.width - transformedRight;
      final mirroredRight = canvasSize.width - transformedLeft;
      transformedLeft = mirroredLeft;
      transformedRight = mirroredRight;
    }
  }

  return Rect.fromLTRB(
    transformedLeft,
    transformedTop,
    transformedRight,
    transformedBottom,
  );
}

class _DebugFaceOverlayPainter extends CustomPainter {
  _DebugFaceOverlayPainter({
    required this.faceBoxes,
    required this.imageSize,
    required this.imageRotationDegrees,
    required this.isFrontCamera,
  });

  final List<Rect> faceBoxes;
  final Size imageSize;
  final int imageRotationDegrees;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFF3B30).withValues(alpha: 0.9);

    for (final face in faceBoxes) {
      final rect = _mapImageRectToCanvas(
        imageRect: face,
        imageSize: imageSize,
        canvasSize: size,
        imageRotationDegrees: imageRotationDegrees,
        isFrontCamera: isFrontCamera,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(12)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DebugFaceOverlayPainter oldDelegate) {
    return oldDelegate.faceBoxes != faceBoxes ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.imageRotationDegrees != imageRotationDegrees ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

class _GuestReticlePainter extends CustomPainter {
  _GuestReticlePainter({
    required this.guestBounds,
    required this.imageSize,
    required this.imageRotationDegrees,
    required this.isFrontCamera,
    required this.isVerified,
  });

  final FaceBounds guestBounds;
  final Size imageSize;
  final int imageRotationDegrees;
  final bool isFrontCamera;
  final bool isVerified;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _mapImageRectToCanvas(
      imageRect: Rect.fromLTWH(
        guestBounds.left,
        guestBounds.top,
        guestBounds.width,
        guestBounds.height,
      ),
      imageSize: imageSize,
      canvasSize: size,
      imageRotationDegrees: imageRotationDegrees,
      isFrontCamera: isFrontCamera,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = (isVerified ? const Color(0xFF2ECC71) : const Color(0xFF00E5FF))
          .withValues(alpha: 0.95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(8), const Radius.circular(16)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuestReticlePainter oldDelegate) {
    return oldDelegate.guestBounds != guestBounds ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.imageRotationDegrees != imageRotationDegrees ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.isVerified != isVerified;
  }
}

class _GuestLivenessBadge extends StatelessWidget {
  const _GuestLivenessBadge({
    required this.guestBounds,
    required this.imageSize,
    required this.imageRotationDegrees,
    required this.isFrontCamera,
    required this.isVerified,
    required this.prompt,
  });

  final FaceBounds guestBounds;
  final Size imageSize;
  final int imageRotationDegrees;
  final bool isFrontCamera;
  final bool isVerified;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final previewSize = MediaQuery.of(context).size;
    final rect = _mapImageRectToCanvas(
      imageRect: Rect.fromLTWH(
        guestBounds.left,
        guestBounds.top,
        guestBounds.width,
        guestBounds.height,
      ),
      imageSize: imageSize,
      canvasSize: previewSize,
      imageRotationDegrees: imageRotationDegrees,
      isFrontCamera: isFrontCamera,
    );

    final left = rect.left.clamp(8.0, previewSize.width - 180);
    final top = (rect.top - 34).clamp(10.0, previewSize.height - 80);

    return Positioned(
      left: left,
      top: top,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVerified
                ? const Color(0xFF2ECC71).withValues(alpha: 0.85)
                : const Color(0xFF00E5FF).withValues(alpha: 0.85),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVerified ? Icons.verified : Icons.sentiment_satisfied_alt,
                size: 15,
                color: isVerified
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 6),
              Text(
                isVerified ? 'Verified' : prompt,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({
    required this.faceBoxes,
    required this.imageSize,
    required this.imageRotationDegrees,
    required this.isFrontCamera,
    required this.color,
    required this.pulse,
  });

  final List<Rect> faceBoxes;
  final Size? imageSize;
  final int imageRotationDegrees;
  final bool isFrontCamera;
  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (0.35 + (pulse * 0.65)).clamp(0.0, 1.0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: alpha);

    final box = _targetRect(size);
    final rrect = RRect.fromRectAndRadius(box, const Radius.circular(20));
    canvas.drawRRect(rrect, stroke);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.25 + (pulse * 0.35));
    final inner = box.deflate(8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(16)),
      highlight,
    );
  }

  Rect _targetRect(Size canvasSize) {
    if (faceBoxes.isEmpty || imageSize == null) {
      final width = canvasSize.width * 0.52;
      final height = canvasSize.height * 0.34;
      return Rect.fromCenter(
        center: canvasSize.center(Offset.zero),
        width: width,
        height: height,
      );
    }

    final face = faceBoxes.first;
    final rect = _mapImageRectToCanvas(
      imageRect: face,
      imageSize: imageSize!,
      canvasSize: canvasSize,
      imageRotationDegrees: imageRotationDegrees,
      isFrontCamera: isFrontCamera,
    );
    return rect.inflate(12);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) {
    return oldDelegate.faceBoxes != faceBoxes ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.imageRotationDegrees != imageRotationDegrees ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.color != color ||
        oldDelegate.pulse != pulse;
  }
}
