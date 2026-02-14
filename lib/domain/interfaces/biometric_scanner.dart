import '../entities/face_vector.dart';

abstract class BiometricScanner<TInput> {
  Future<FaceVector?> captureFace(TInput input);
}
