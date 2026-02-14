import 'package:isar/isar.dart';

import '../../core/interfaces/crypto_provider.dart';
import '../../core/utils/app_logger.dart';
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
    AppLogger.log('DB', 'Saving proof to Isar');
    final proofHash = await proof.computeProofHash(_crypto);
    final model = MeetingProofModel.fromDomain(proof, proofHash: proofHash);

    late int savedId;
    await _isar.writeTxn(() async {
      savedId = await _isar.meetingProofModels.put(model);
    });
    AppLogger.log('DB', 'Proof saved to DB (id=$savedId, hash=$proofHash)');
  }

  @override
  Future<List<MeetingProof>> getAllProofs() async {
    AppLogger.log('DB', 'Loading all proofs from Isar');
    final models = await _isar.meetingProofModels.where().findAll();
    models.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final proofs = <MeetingProof>[];
    for (final model in models) {
      final proof = model.toDomain();
      if (!await _isProofModelValid(model: model, proof: proof)) {
        AppLogger.error(
          'DB',
          'Skipping invalid/tampered proof (id=${model.id}, hash=${model.proofHash})',
        );
        continue;
      }
      proofs.add(proof);
    }

    AppLogger.log('DB', 'Loaded ${proofs.length} valid proof(s) from Isar');
    return proofs;
  }

  @override
  Future<MeetingProof?> getLatestProof() async {
    AppLogger.log('DB', 'Loading latest proof from Isar');
    final models = await _isar.meetingProofModels.where().findAll();
    models.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final model in models) {
      final proof = model.toDomain();
      if (await _isProofModelValid(model: model, proof: proof)) {
        AppLogger.log('DB', 'Latest valid proof hash=${model.proofHash}');
        return proof;
      }
    }

    AppLogger.log('DB', 'No valid proof found in Isar');
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
