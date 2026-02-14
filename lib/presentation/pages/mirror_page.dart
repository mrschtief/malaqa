import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di/service_locator.dart';
import '../../domain/entities/face_vector.dart';
import '../../domain/interfaces/biometric_scanner.dart';
import '../../domain/services/face_matcher_service.dart';
import '../../domain/services/meeting_participant_resolver.dart';

class MirrorPage extends StatefulWidget {
  const MirrorPage({super.key});

  @override
  State<MirrorPage> createState() => _MirrorPageState();
}

class _MirrorPageState extends State<MirrorPage> {
  CameraController? _cameraController;
  late final FaceDetector _faceDetector;

  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  bool _isScanning = false;

  CameraImage? _latestFrame;
  List<Rect> _latestFaceBoxes = const <Rect>[];
  Size? _latestImageSize;
  FaceVector? _ownerReferenceVector;
  String _status =
      'Ready: capture owner first, then scan with two people in frame.';

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Camera permission denied';
      });
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'No camera available';
      });
      return;
    }

    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    await controller.startImageStream(_processCameraFrame);

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
      _isCameraReady = true;
      _status =
          'Ready: capture owner first, then scan with two people in frame.';
    });
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || !mounted) {
      return;
    }

    _latestFrame = image;
    _latestImageSize = Size(image.width.toDouble(), image.height.toDouble());
    _isProcessingFrame = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        return;
      }
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        return;
      }
      final sortedBoxes = faces.map((face) => face.boundingBox).toList()
        ..sort(
          (a, b) => (b.width * b.height).compareTo(a.width * a.height),
        );
      setState(() {
        _latestFaceBoxes = List<Rect>.unmodifiable(sortedBoxes);
      });
    } catch (error) {
      debugPrint('Frame processing failed: $error');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) {
      return null;
    }

    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
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

    final bytes = _concatenatePlanes(image.planes);
    if (bytes.isEmpty) {
      return null;
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final totalLength = planes.fold<int>(
      0,
      (sum, plane) => sum + plane.bytes.length,
    );
    final allBytes = Uint8List(totalLength);
    var offset = 0;
    for (final plane in planes) {
      allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return allBytes;
  }

  Future<void> _scanMe() async {
    if (_ownerReferenceVector == null) {
      await _captureOwnerReference();
      return;
    }
    await _scanDuoMeeting();
  }

  Future<void> _captureOwnerReference() async {
    if (_isScanning) {
      return;
    }

    final frame = _latestFrame;
    if (frame == null) {
      setState(() {
        _status = 'No frame available yet';
      });
      return;
    }

    if (_latestFaceBoxes.isEmpty) {
      setState(() {
        _status = 'No face detected';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Capturing owner reference...';
    });

    final scanner =
        getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>();
    final vector = await scanner.captureFace(
      _scanRequest(
        frame,
        faceBounds: _faceBoundsFromRect(_latestFaceBoxes.first),
      ),
    );

    if (!mounted) {
      return;
    }

    if (vector == null) {
      setState(() {
        _isScanning = false;
        _status = 'Owner capture failed';
      });
      return;
    }

    setState(() {
      _ownerReferenceVector = vector;
      _isScanning = false;
      _status = 'Owner ready. Add second person and tap Scan Duo.';
    });
  }

  Future<void> _scanDuoMeeting() async {
    if (_isScanning) {
      return;
    }

    final ownerReference = _ownerReferenceVector;
    if (ownerReference == null) {
      setState(() {
        _status = 'Capture owner first';
      });
      return;
    }

    final frame = _latestFrame;
    if (frame == null) {
      setState(() {
        _status = 'No frame available yet';
      });
      return;
    }

    if (_latestFaceBoxes.length < 2) {
      setState(() {
        _status = 'Need two faces in frame';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning duo...';
    });

    final scanner =
        getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>();
    final resolver = getIt<MeetingParticipantResolver>();
    final faceMatcher = getIt<FaceMatcherService>();

    final faceBounds = _latestFaceBoxes
        .take(2)
        .map(_faceBoundsFromRect)
        .toList(growable: false);
    final vectors = await scanner.scanFaces(
      _scanRequest(frame),
      faceBounds,
    );

    if (!mounted) {
      return;
    }

    if (vectors.length < 2) {
      setState(() {
        _isScanning = false;
        _status = 'Vector generation failed for duo';
      });
      return;
    }

    final resolved = resolver.resolve(
      detectedVectors: vectors,
      ownerVector: ownerReference,
      threshold: 0.75,
    );

    if (!resolved.isOwnerDetected || resolved.owner == null) {
      setState(() {
        _isScanning = false;
        _status = 'Owner not recognized in duo frame';
      });
      return;
    }

    if (!resolved.isGuestDetected || resolved.guest == null) {
      setState(() {
        _isScanning = false;
        _status = 'Guest not recognized in duo frame';
      });
      return;
    }

    final ownerScore = faceMatcher.compare(ownerReference, resolved.owner!);
    final ownerGuestScore =
        faceMatcher.compare(resolved.owner!, resolved.guest!);

    setState(() {
      _isScanning = false;
      _status =
          'Duo ready | owner=${ownerScore.toStringAsFixed(3)} guest=${ownerGuestScore.toStringAsFixed(3)}';
    });
  }

  BiometricScanRequest<CameraImage> _scanRequest(
    CameraImage frame, {
    FaceBounds? faceBounds,
  }) {
    return BiometricScanRequest<CameraImage>(
      image: frame,
      faceBounds: faceBounds,
      rotationDegrees: _cameraController!.description.sensorOrientation,
      isFrontCamera: _cameraController!.description.lensDirection ==
          CameraLensDirection.front,
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

  void _resetOwnerReference() {
    if (_isScanning) {
      return;
    }
    setState(() {
      _ownerReferenceVector = null;
      _status = 'Owner reset. Capture owner again.';
    });
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
      controller.dispose();
    }
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: !_isCameraReady || _cameraController == null
            ? Center(
                child: Text(
                  _status,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_cameraController!),
                  if (_latestFaceBoxes.isNotEmpty && _latestImageSize != null)
                    CustomPaint(
                      painter: _FaceBoxesPainter(
                        faceBoxes: _latestFaceBoxes,
                        imageSize: _latestImageSize!,
                        isFrontCamera:
                            _cameraController!.description.lensDirection ==
                                CameraLensDirection.front,
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(170),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Faces: ${_latestFaceBoxes.length} | Owner: ${_ownerReferenceVector == null ? 'missing' : 'ready'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Status: $_status',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _isScanning ? null : _scanMe,
                              child: Text(
                                _isScanning
                                    ? 'Scanning...'
                                    : _ownerReferenceVector == null
                                        ? 'Set Me (Owner)'
                                        : 'Scan Duo',
                              ),
                            ),
                            if (_ownerReferenceVector != null)
                              OutlinedButton(
                                onPressed:
                                    _isScanning ? null : _resetOwnerReference,
                                child: const Text('Reset Owner'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FaceBoxesPainter extends CustomPainter {
  _FaceBoxesPainter({
    required this.faceBoxes,
    required this.imageSize,
    required this.isFrontCamera,
  });

  final List<Rect> faceBoxes;
  final Size imageSize;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < faceBoxes.length; index++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = index == 0 ? Colors.greenAccent : Colors.orangeAccent;

      final faceBox = faceBoxes[index];
      // TODO(milestone-f): Improve mapping for rotation-specific coordinates.
      Rect rect = Rect.fromLTWH(
        faceBox.left * (size.width / imageSize.width),
        faceBox.top * (size.height / imageSize.height),
        faceBox.width * (size.width / imageSize.width),
        faceBox.height * (size.height / imageSize.height),
      );

      if (isFrontCamera) {
        rect = Rect.fromLTRB(
          size.width - rect.right,
          rect.top,
          size.width - rect.left,
          rect.bottom,
        );
      }

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceBoxesPainter oldDelegate) {
    if (oldDelegate.faceBoxes.length != faceBoxes.length) {
      return true;
    }
    for (var i = 0; i < faceBoxes.length; i++) {
      if (oldDelegate.faceBoxes[i] != faceBoxes[i]) {
        return true;
      }
    }
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
