import '../../core/interfaces/crypto_provider.dart';
import '../entities/meeting_proof.dart';

class VerifyMeetingProofUseCase {
  VerifyMeetingProofUseCase(this._crypto);

  final CryptoProvider _crypto;

  Future<bool> execute(MeetingProof proof) {
    return proof.verifyProof(_crypto);
  }
}
