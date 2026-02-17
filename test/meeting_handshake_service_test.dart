import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/crypto/ed25519_crypto_provider.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/domain/entities/face_vector.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/services/meeting_handshake_service.dart';

void main() {
  test('createDraftProof builds unsigned payload with deterministic fields',
      () async {
    final service = MeetingHandshakeService(Ed25519CryptoProvider());

    final draft = await service.createDraftProof(
      vectorA: FaceVector(const [1.0, 0.0, 0.0]),
      vectorB: FaceVector(const [0.0, 1.0, 0.0]),
      location: const LocationPoint(latitude: 52.52, longitude: 13.405),
      previousMeetingHash: '0000',
      timestamp: DateTime.utc(2026, 2, 17, 12, 0, 0),
    );

    expect(draft.signatures, isEmpty);
    expect(draft.previousMeetingHash, '0000');
    expect(draft.saltedVectorHash, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(draft.location.latitude, closeTo(52.52, 0.0001));
  });

  test('signProofPayload produces verifiable signatures for proof payload',
      () async {
    final crypto = Ed25519CryptoProvider();
    final service = MeetingHandshakeService(crypto);
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final draft = await service.createDraftProof(
      vectorA: FaceVector(const [1.0, 0.0, 0.0]),
      vectorB: FaceVector(const [0.0, 1.0, 0.0]),
      location: const LocationPoint(latitude: 52.52, longitude: 13.405),
      previousMeetingHash: '0000',
      timestamp: DateTime.utc(2026, 2, 17, 12, 30, 0),
    );
    final aliceSignature =
        await service.signProofPayload(participant: alice, proof: draft);
    final bobSignature =
        await service.signProofPayload(participant: bob, proof: draft);
    final signed = draft.copyWith(signatures: [aliceSignature, bobSignature]);

    expect(await signed.verifyProof(crypto), isTrue);
  });
}
