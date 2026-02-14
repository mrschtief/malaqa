import '../../core/crypto/ed25519_crypto_provider.dart';
import '../../core/interfaces/crypto_provider.dart';
import 'location_point.dart';
import 'participant_signature.dart';

class MeetingProof {
  MeetingProof({
    required this.timestamp,
    required this.location,
    required this.saltedVectorHash,
    required this.previousMeetingHash,
    required List<ParticipantSignature> signatures,
  }) : signatures = List<ParticipantSignature>.unmodifiable(signatures);

  final String timestamp;
  final LocationPoint location;
  final String saltedVectorHash;
  final String previousMeetingHash;
  final List<ParticipantSignature> signatures;

  String canonicalPayload() {
    return [
      timestamp,
      location.toCanonicalString(),
      saltedVectorHash,
      previousMeetingHash,
    ].join('|');
  }

  String canonicalProof() {
    final sortedSigs = [...signatures]
      ..sort((a, b) => a.publicKeyHex.compareTo(b.publicKeyHex));
    final sigPart = sortedSigs.map((s) => s.toCanonicalString()).join('|');
    return '${canonicalPayload()}|$sigPart';
  }

  Future<String> computeProofHash(CryptoProvider crypto) async {
    final digest = await crypto.sha256(canonicalProof().codeUnits);
    return bytesToHex(digest);
  }

  Future<bool> verifyProof(CryptoProvider crypto) async {
    if (signatures.length < 2) {
      return false;
    }
    if (previousMeetingHash.isEmpty ||
        !RegExp(r'^[a-f0-9]+$').hasMatch(previousMeetingHash)) {
      return false;
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(saltedVectorHash)) {
      return false;
    }
    if (DateTime.tryParse(timestamp) == null) {
      return false;
    }
    if (location.latitude < -90 ||
        location.latitude > 90 ||
        location.longitude < -180 ||
        location.longitude > 180) {
      return false;
    }

    final payload = canonicalPayload().codeUnits;
    for (final signer in signatures) {
      if (!RegExp(r'^[a-f0-9]+$').hasMatch(signer.publicKeyHex) ||
          !RegExp(r'^[a-f0-9]+$').hasMatch(signer.signatureHex)) {
        return false;
      }
      final valid = await crypto.verify(
        message: payload,
        signature: hexToBytes(signer.signatureHex),
        publicKey: hexToBytes(signer.publicKeyHex),
      );
      if (!valid) {
        return false;
      }
    }
    return true;
  }
}
