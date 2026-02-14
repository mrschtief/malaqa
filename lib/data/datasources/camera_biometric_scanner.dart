import 'dart:math';

import 'package:camera/camera.dart';

import '../../domain/entities/face_vector.dart';
import '../../domain/interfaces/biometric_scanner.dart';

class CameraBiometricScanner implements BiometricScanner<CameraImage> {
  @override
  Future<FaceVector?> captureFace(CameraImage image) async {
    if (image.planes.isEmpty || image.width == 0 || image.height == 0) {
      return null;
    }

    // TODO(milestone-f): Convert YUV/RGBA frame and run TFLite MobileFaceNet.
    // For milestone E we return a deterministic pseudo-vector to validate flow.
    final seed = image.planes.first.bytes
        .take(64)
        .fold<int>(0, (acc, b) => ((acc * 31) + b) & 0x7fffffff);
    final random = Random(seed);

    final embedding = List<double>.generate(512, (_) => random.nextDouble());
    return FaceVector(embedding);
  }
}
