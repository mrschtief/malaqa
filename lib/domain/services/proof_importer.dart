import 'dart:convert';

import '../../core/interfaces/crypto_provider.dart';
import '../../core/utils/app_logger.dart';
import '../entities/meeting_proof.dart';
import '../repositories/chain_repository.dart';
import '../use_cases/verify_meeting_proof_use_case.dart';

enum ImportStatus {
  success,
  duplicate,
  invalid,
}

class ImportResult {
  const ImportResult({
    required this.status,
    required this.message,
  });

  final ImportStatus status;
  final String message;
}

class ProofImporter {
  ProofImporter({
    required ChainRepository chainRepository,
    required VerifyMeetingProofUseCase verifyProofUseCase,
    required CryptoProvider crypto,
  })  : _chainRepository = chainRepository,
        _verifyProofUseCase = verifyProofUseCase,
        _crypto = crypto;

  final ChainRepository _chainRepository;
  final VerifyMeetingProofUseCase _verifyProofUseCase;
  final CryptoProvider _crypto;

  Future<ImportResult> importProof(String jsonPayload) async {
    try {
      final decoded = jsonDecode(jsonPayload);
      if (decoded is! Map<String, dynamic>) {
        return const ImportResult(
          status: ImportStatus.invalid,
          message: 'Invalid proof payload format.',
        );
      }

      final proof = MeetingProof.fromJson(decoded);
      final isValid = await _verifyProofUseCase.execute(proof);
      if (!isValid) {
        return const ImportResult(
          status: ImportStatus.invalid,
          message: 'Proof signature verification failed.',
        );
      }

      final incomingHash = await proof.computeProofHash(_crypto);
      final existingProofs = await _chainRepository.getAllProofs();
      for (final existing in existingProofs) {
        final hash = await existing.computeProofHash(_crypto);
        if (hash == incomingHash) {
          return const ImportResult(
            status: ImportStatus.duplicate,
            message: 'Proof already exists on this device.',
          );
        }
      }

      await _chainRepository.saveProof(proof);
      AppLogger.log(
        'IMPORT',
        'Imported proof hash=$incomingHash',
      );
      return const ImportResult(
        status: ImportStatus.success,
        message: 'Meeting verified via QR.',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'IMPORT',
        'Failed to import proof payload',
        error: error,
        stackTrace: stackTrace,
      );
      return const ImportResult(
        status: ImportStatus.invalid,
        message: 'Invalid proof payload.',
      );
    }
  }
}
