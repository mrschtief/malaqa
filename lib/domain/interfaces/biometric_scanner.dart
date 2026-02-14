import '../entities/face_vector.dart';

class FaceBounds {
  const FaceBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
}

class BiometricScanRequest<TImage> {
  const BiometricScanRequest({
    required this.image,
    required this.faceBounds,
    required this.rotationDegrees,
    this.isFrontCamera = false,
  });

  final TImage image;
  final FaceBounds faceBounds;
  final int rotationDegrees;
  final bool isFrontCamera;
}

abstract class BiometricScanner<TInput> {
  Future<FaceVector?> captureFace(TInput input);
}
