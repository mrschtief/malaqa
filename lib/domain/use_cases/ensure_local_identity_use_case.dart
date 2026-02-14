import '../../core/identity.dart';
import '../../core/utils/app_logger.dart';
import '../repositories/identity_repository.dart';

class EnsureLocalIdentityUseCase {
  EnsureLocalIdentityUseCase(this._identityRepository);

  final IdentityRepository _identityRepository;

  Future<Ed25519Identity> execute({String defaultName = 'local-user'}) async {
    AppLogger.log('BOOT', 'Ensuring local identity');
    final existing = await _identityRepository.getIdentity();
    if (existing != null) {
      AppLogger.log(
        'BOOT',
        'Identity loaded (${existing.publicKeyHex.substring(0, 16)}...)',
      );
      return existing;
    }

    final identity = await Identity.create(name: defaultName);
    await _identityRepository.saveIdentity(identity);
    AppLogger.log(
      'BOOT',
      'Identity created (${identity.publicKeyHex.substring(0, 16)}...)',
    );
    return identity;
  }
}
