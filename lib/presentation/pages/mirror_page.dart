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
  Rect? _latestFaceBox;
  Size? _latestImageSize;
  FaceVector? _referenceVector;
  String _status = 'Similarity: 0.0';

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
      _status = 'Similarity: 0.0';
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
      setState(() {
        _latestFaceBox = faces.isNotEmpty ? faces.first.boundingBox : null;
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

    if (_latestFaceBox == null) {
      setState(() {
        _status = 'No face detected';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
    });

    final scanner =
        getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>();
    final vector = await scanner.captureFace(
      BiometricScanRequest<CameraImage>(
        image: frame,
        faceBounds: FaceBounds(
          left: _latestFaceBox!.left,
          top: _latestFaceBox!.top,
          right: _latestFaceBox!.right,
          bottom: _latestFaceBox!.bottom,
        ),
        rotationDegrees: _cameraController!.description.sensorOrientation,
        isFrontCamera: _cameraController!.description.lensDirection ==
            CameraLensDirection.front,
      ),
    );

    if (!mounted) {
      return;
    }

    String nextStatus;
    if (vector == null) {
      nextStatus = 'No vector generated';
    } else if (_referenceVector == null) {
      _referenceVector = vector;
      nextStatus = 'Reference captured. Scan again for similarity.';
    } else {
      final faceMatcher = getIt<FaceMatcherService>();
      final similarity = faceMatcher.compare(_referenceVector!, vector);
      final isMatch = faceMatcher.isMatch(_referenceVector!, vector);
      nextStatus =
          'Similarity: ${similarity.toStringAsFixed(4)} | Match: ${isMatch ? 'yes' : 'no'}';
      _referenceVector = null;
    }

    setState(() {
      _isScanning = false;
      _status = nextStatus;
    });

    if (vector != null) {
      debugPrint('Vector generated (${vector.values.length})');
    }
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
                  if (_latestFaceBox != null && _latestImageSize != null)
                    CustomPaint(
                      painter: _FaceBoxPainter(
                        faceBox: _latestFaceBox!,
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
                              'Status: $_status',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _isScanning ? null : _scanMe,
                              child:
                                  Text(_isScanning ? 'Scanning...' : 'Scan Me'),
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

class _FaceBoxPainter extends CustomPainter {
  _FaceBoxPainter({
    required this.faceBox,
    required this.imageSize,
    required this.isFrontCamera,
  });

  final Rect faceBox;
  final Size imageSize;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.greenAccent;

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

  @override
  bool shouldRepaint(covariant _FaceBoxPainter oldDelegate) {
    return oldDelegate.faceBox != faceBox ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
