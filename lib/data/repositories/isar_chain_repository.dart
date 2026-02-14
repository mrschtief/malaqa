import 'package:isar/isar.dart';

import '../../core/interfaces/crypto_provider.dart';
import '../../domain/entities/meeting_proof.dart';
import '../../domain/repositories/chain_repository.dart';
import '../../domain/use_cases/verify_meeting_proof_use_case.dart';
import '../models/meeting_proof_model.dart';

class IsarChainRepository implements ChainRepository {
  IsarChainRepository(
    this._isar,
    this._verifyProofUseCase,
    this._crypto,
  );

  final Isar _isar;
  final VerifyMeetingProofUseCase _verifyProofUseCase;
  final CryptoProvider _crypto;

  @override
  Future<void> saveProof(MeetingProof proof) async {
    final proofHash = await proof.computeProofHash(_crypto);
    final model = MeetingProofModel.fromDomain(proof, proofHash: proofHash);

    await _isar.writeTxn(() async {
      await _isar.meetingProofModels.put(model);
    });
  }

  @override
  Future<List<MeetingProof>> getAllProofs() async {
    final models = await _isar.meetingProofModels.where().findAll();
    models.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final proofs = <MeetingProof>[];
    for (final model in models) {
      final proof = model.toDomain();
      if (!await _isProofModelValid(model: model, proof: proof)) {
        continue;
      }
      proofs.add(proof);
    }

    return proofs;
  }

  @override
  Future<MeetingProof?> getLatestProof() async {
    final models = await _isar.meetingProofModels.where().findAll();
    models.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final model in models) {
      final proof = model.toDomain();
      if (await _isProofModelValid(model: model, proof: proof)) {
        return proof;
      }
    }

    return null;
  }

  Future<bool> _isProofModelValid({
    required MeetingProofModel model,
    required MeetingProof proof,
  }) async {
    final signaturesValid = await _verifyProofUseCase.execute(proof);
    if (!signaturesValid) {
      return false;
    }

    final recomputedHash = await proof.computeProofHash(_crypto);
    return recomputedHash == model.proofHash;
  }
}
