import '../../core/crypto/ed25519_crypto_provider.dart';
import '../../core/identity.dart';
import '../../core/interfaces/crypto_provider.dart';
import '../entities/face_vector.dart';
import '../entities/location_point.dart';
import '../entities/meeting_proof.dart';
import '../entities/participant_signature.dart';

class MeetingHandshakeService {
  MeetingHandshakeService(this._crypto);

  final CryptoProvider _crypto;

  Future<MeetingProof> createProof({
    required Identity participantA,
    required Identity participantB,
    required FaceVector vectorA,
    required FaceVector vectorB,
    required LocationPoint location,
    required String previousMeetingHash,
    DateTime? timestamp,
  }) async {
    final meetingSalt = _crypto.randomBytes(16);
    final saltedA = await vectorA.saltedHash(
      salt: meetingSalt,
      hasher: _crypto.sha256,
    );
    final saltedB = await vectorB.saltedHash(
      salt: meetingSalt,
      hasher: _crypto.sha256,
    );

    final ordered = [
      (participantA.publicKeyHex, saltedA),
      (participantB.publicKeyHex, saltedB),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

    final combined = '${ordered[0].$2}|${ordered[1].$2}';
    final saltedVectorHash = bytesToHex(await _crypto.sha256(combined.codeUnits));

    final proof = MeetingProof(
      timestamp: (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      location: location,
      saltedVectorHash: saltedVectorHash,
      previousMeetingHash: previousMeetingHash,
      signatures: const [],
    );

    final payload = proof.canonicalPayload().codeUnits;

    final signatureA = await participantA.signPayload(
      payload: payload,
      crypto: _crypto,
    );
    final signatureB = await participantB.signPayload(
      payload: payload,
      crypto: _crypto,
    );

    return MeetingProof(
      timestamp: proof.timestamp,
      location: proof.location,
      saltedVectorHash: proof.saltedVectorHash,
      previousMeetingHash: proof.previousMeetingHash,
      signatures: [
        ParticipantSignature(
          publicKeyHex: participantA.publicKeyHex,
          signatureHex: bytesToHex(signatureA),
        ),
        ParticipantSignature(
          publicKeyHex: participantB.publicKeyHex,
          signatureHex: bytesToHex(signatureB),
        ),
      ],
    );
  }
}
