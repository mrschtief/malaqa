import '../../core/identity.dart';
import '../repositories/identity_repository.dart';

class EnsureLocalIdentityUseCase {
  EnsureLocalIdentityUseCase(this._identityRepository);

  final IdentityRepository _identityRepository;

  Future<Ed25519Identity> execute({String defaultName = 'local-user'}) async {
    final existing = await _identityRepository.getIdentity();
    if (existing != null) {
      return existing;
    }

    final identity = await Identity.create(name: defaultName);
    await _identityRepository.saveIdentity(identity);
    return identity;
  }
}
