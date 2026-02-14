import '../../core/identity.dart';
import '../entities/face_vector.dart';

abstract class IdentityRepository {
  Future<void> saveIdentity(Ed25519Identity identity);

  Future<Ed25519Identity?> getIdentity();

  Future<void> saveOwnerFaceVector(FaceVector vector);

  Future<FaceVector?> getOwnerFaceVector();
}
