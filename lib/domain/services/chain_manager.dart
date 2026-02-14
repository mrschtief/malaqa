import '../../core/interfaces/crypto_provider.dart';
import '../entities/meeting_proof.dart';

class ChainManager {
  ChainManager(this._crypto);

  final CryptoProvider _crypto;

  final List<MeetingProof> _chain = [];

  List<MeetingProof> get chain => List<MeetingProof>.unmodifiable(_chain);

  void addProof(MeetingProof proof) => _chain.add(proof);

  Future<bool> isValidChain(List<MeetingProof> chain) async {
    if (chain.isEmpty) {
      return true;
    }

    if (chain.first.previousMeetingHash != '0000') {
      return false;
    }

    for (var i = 0; i < chain.length; i++) {
      final current = chain[i];
      final proofValid = await current.verifyProof(_crypto);
      if (!proofValid) {
        return false;
      }

      if (i == 0) {
        continue;
      }

      final prev = chain[i - 1];
      final prevHash = await prev.computeProofHash(_crypto);
      if (current.previousMeetingHash != prevHash) {
        return false;
      }
    }

    return true;
  }
}
