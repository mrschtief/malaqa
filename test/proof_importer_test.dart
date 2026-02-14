import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/crypto/ed25519_crypto_provider.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/domain/entities/face_vector.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/repositories/chain_repository.dart';
import 'package:malaqa/domain/services/meeting_handshake_service.dart';
import 'package:malaqa/domain/services/proof_importer.dart';
import 'package:malaqa/domain/use_cases/verify_meeting_proof_use_case.dart';

class InMemoryChainRepository implements ChainRepository {
  final List<MeetingProof> _proofs = [];

  @override
  Future<List<MeetingProof>> getAllProofs() async {
    return List<MeetingProof>.unmodifiable(_proofs);
  }

  @override
  Future<MeetingProof?> getLatestProof() async {
    if (_proofs.isEmpty) {
      return null;
    }
    return _proofs.last;
  }

  @override
  Future<void> saveProof(MeetingProof proof) async {
    _proofs.add(proof);
  }
}

Future<MeetingProof> _buildValidProof() async {
  final crypto = Ed25519CryptoProvider();
  final handshake = MeetingHandshakeService(crypto);
  final alice = await Identity.create(name: 'alice');
  final bob = await Identity.create(name: 'bob');

  return handshake.createProof(
    participantA: alice,
    participantB: bob,
    vectorA: FaceVector(List<double>.filled(192, 0.12)),
    vectorB: FaceVector(List<double>.filled(192, 0.34)),
    location: const LocationPoint(latitude: 52.5200, longitude: 13.4050),
    previousMeetingHash: '0000',
    timestamp: DateTime.utc(2026, 2, 14, 18, 0, 0),
  );
}

void main() {
  test('ProofImporter imports a valid proof', () async {
    final repository = InMemoryChainRepository();
    final crypto = Ed25519CryptoProvider();
    final importer = ProofImporter(
      chainRepository: repository,
      verifyProofUseCase: VerifyMeetingProofUseCase(crypto),
      crypto: crypto,
    );
    final proof = await _buildValidProof();
    final payload = jsonEncode(proof.toJson());

    final result = await importer.importProof(payload);

    expect(result.status, ImportStatus.success);
    expect((await repository.getAllProofs()).length, 1);
  });

  test('ProofImporter returns duplicate for existing proof', () async {
    final repository = InMemoryChainRepository();
    final crypto = Ed25519CryptoProvider();
    final importer = ProofImporter(
      chainRepository: repository,
      verifyProofUseCase: VerifyMeetingProofUseCase(crypto),
      crypto: crypto,
    );
    final proof = await _buildValidProof();
    final payload = jsonEncode(proof.toJson());

    final firstImport = await importer.importProof(payload);
    final secondImport = await importer.importProof(payload);

    expect(firstImport.status, ImportStatus.success);
    expect(secondImport.status, ImportStatus.duplicate);
    expect((await repository.getAllProofs()).length, 1);
  });

  test('ProofImporter rejects invalid proof payload', () async {
    final repository = InMemoryChainRepository();
    final crypto = Ed25519CryptoProvider();
    final importer = ProofImporter(
      chainRepository: repository,
      verifyProofUseCase: VerifyMeetingProofUseCase(crypto),
      crypto: crypto,
    );

    final result = await importer.importProof('{"foo":"bar"}');

    expect(result.status, ImportStatus.invalid);
    expect((await repository.getAllProofs()), isEmpty);
  });
}
