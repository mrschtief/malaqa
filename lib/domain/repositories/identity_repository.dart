import '../../core/identity.dart';

abstract class IdentityRepository {
  Future<void> saveIdentity(Ed25519Identity identity);

  Future<Ed25519Identity?> getIdentity();
}
