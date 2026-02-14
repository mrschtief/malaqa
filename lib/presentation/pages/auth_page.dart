import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di/service_locator.dart';
import '../../domain/interfaces/biometric_scanner.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/meeting/meeting_cubit.dart';
import 'journey_page.dart';
import 'profile_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late final FaceDetector _faceDetector;
  late final AnimationController _reticlePulseController;

  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  bool _isCreatingIdentity = false;

  CameraImage? _latestFrame;
  List<Rect> _latestFaceBoxes = const <Rect>[];
  Size? _latestImageSize;
  String _cameraStatus = 'Starting camera...';

  @override
  void initState() {
    super.initState();
    _reticlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeCamera();
    unawaited(context.read<AuthCubit>().checkIdentity());
  }

  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraStatus = 'Camera permission denied';
      });
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
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
      _cameraStatus = 'Looking for you...';
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
      final sortedBoxes = faces.map((face) => face.boundingBox).toList()
        ..sort(
          (a, b) => (b.width * b.height).compareTo(a.width * a.height),
        );

      if (!mounted) {
        return;
      }

      setState(() {
        _latestFaceBoxes = List<Rect>.unmodifiable(sortedBoxes);
      });

      final state = context.read<AuthCubit>().state;
      if (state is AuthScanning && sortedBoxes.isNotEmpty) {
        final request = _scanRequest(image);
        final bounds = sortedBoxes
            .take(2)
            .map(_faceBoundsFromRect)
            .toList(growable: false);
        unawaited(context.read<AuthCubit>().processFrame(request, bounds));
      }
      if (state is AuthAuthenticated && sortedBoxes.isNotEmpty) {
        final request = _scanRequest(image);
        final bounds =
            sortedBoxes.map(_faceBoundsFromRect).toList(growable: false);
        unawaited(context.read<MeetingCubit>().processFrame(request, bounds));
      }
    } catch (_) {
      // Keep camera loop resilient and silent in UI for now.
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

  BiometricScanRequest<CameraImage> _scanRequest(
    CameraImage image, {
    FaceBounds? faceBounds,
  }) {
    return BiometricScanRequest<CameraImage>(
      image: image,
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

  Future<void> _createIdentityFromCurrentFace() async {
    if (_isCreatingIdentity) {
      return;
    }
    final frame = _latestFrame;
    if (frame == null || _latestFaceBoxes.isEmpty) {
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
      final scanner =
          getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>();
      final ownerVector = await scanner.captureFace(
        _scanRequest(
          frame,
          faceBounds: _faceBoundsFromRect(_latestFaceBoxes.first),
        ),
      );
      if (ownerVector == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face vector capture failed.')),
        );
        return;
      }

      await context.read<AuthCubit>().createIdentityFromVector(
            ownerVector: ownerVector,
          );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingIdentity = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reticlePulseController.dispose();
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
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
          context.read<MeetingCubit>().setAuthenticated(
                identity: state.identity,
                ownerVector: state.ownerVector,
              );
          return;
        }
        context.read<MeetingCubit>().clearAuthentication();
      },
      builder: (context, state) {
        return BlocListener<MeetingCubit, MeetingState>(
          listener: (context, meetingState) {
            if (meetingState is! MeetingSuccess) {
              return;
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
                                    isFrontCamera: _cameraController!
                                            .description.lensDirection ==
                                        CameraLensDirection.front,
                                    color: reticleColor,
                                    pulse: _reticlePulseController.value,
                                  ),
                                );
                              },
                            ),
                            if (guestBounds != null && _latestImageSize != null)
                              CustomPaint(
                                painter: _GuestReticlePainter(
                                  guestBounds: guestBounds,
                                  imageSize: _latestImageSize!,
                                  isFrontCamera: _cameraController!
                                          .description.lensDirection ==
                                      CameraLensDirection.front,
                                ),
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
                                    onOpenJourney: () => Navigator.of(context)
                                        .push(JourneyPage.route()),
                                    onOpenProfile: () => Navigator.of(context)
                                        .push(ProfilePage.route()),
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
      AuthScanning _ => 'Looking for you...',
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
      MeetingReady _ => 'Guest detected. Capture is ready.',
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
    required this.onOpenJourney,
    required this.onOpenProfile,
  });

  final AuthState state;
  final MeetingState meetingState;
  final VoidCallback onCapture;
  final VoidCallback onOpenJourney;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final name = state is AuthAuthenticated
        ? (state as AuthAuthenticated).identity.name
        : 'User';
    final isReady = meetingState is MeetingReady;
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
              onPressed: onOpenJourney,
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
                MeetingReady _ => 'Guest locked. Press capture.',
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

class _GuestReticlePainter extends CustomPainter {
  _GuestReticlePainter({
    required this.guestBounds,
    required this.imageSize,
    required this.isFrontCamera,
  });

  final FaceBounds guestBounds;
  final Size imageSize;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    var rect = Rect.fromLTWH(
      guestBounds.left * (size.width / imageSize.width),
      guestBounds.top * (size.height / imageSize.height),
      guestBounds.width * (size.width / imageSize.width),
      guestBounds.height * (size.height / imageSize.height),
    );
    if (isFrontCamera) {
      rect = Rect.fromLTRB(
        size.width - rect.right,
        rect.top,
        size.width - rect.left,
        rect.bottom,
      );
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(8), const Radius.circular(16)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuestReticlePainter oldDelegate) {
    return oldDelegate.guestBounds != guestBounds ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({
    required this.faceBoxes,
    required this.imageSize,
    required this.isFrontCamera,
    required this.color,
    required this.pulse,
  });

  final List<Rect> faceBoxes;
  final Size? imageSize;
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
    var rect = Rect.fromLTWH(
      face.left * (canvasSize.width / imageSize!.width),
      face.top * (canvasSize.height / imageSize!.height),
      face.width * (canvasSize.width / imageSize!.width),
      face.height * (canvasSize.height / imageSize!.height),
    );

    if (isFrontCamera) {
      rect = Rect.fromLTRB(
        canvasSize.width - rect.right,
        rect.top,
        canvasSize.width - rect.left,
        rect.bottom,
      );
    }

    return rect.inflate(12);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) {
    return oldDelegate.faceBoxes != faceBoxes ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.color != color ||
        oldDelegate.pulse != pulse;
  }
}
