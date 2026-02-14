import '../entities/meeting_proof.dart';
import '../services/chain_manager.dart';

class ValidateChainUseCase {
  ValidateChainUseCase(this._chainManager);

  final ChainManager _chainManager;

  Future<bool> execute(List<MeetingProof> chain) {
    return _chainManager.isValidChain(chain);
  }
}
