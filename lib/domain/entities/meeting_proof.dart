import 'dart:convert';

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
    this.ipfsCid,
  }) : signatures = List<ParticipantSignature>.unmodifiable(signatures);

  final String timestamp;
  final LocationPoint location;
  final String saltedVectorHash;
  final String previousMeetingHash;
  final List<ParticipantSignature> signatures;
  final String? ipfsCid;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'location': location.toJson(),
      'saltedVectorHash': saltedVectorHash,
      'previousMeetingHash': previousMeetingHash,
      'signatures': signatures.map((s) => s.toJson()).toList(),
      if (ipfsCid != null) 'ipfsCid': ipfsCid,
    };
  }

  factory MeetingProof.fromJson(Map<String, dynamic> json) {
    return MeetingProof(
      timestamp: json['timestamp'] as String,
      location:
          LocationPoint.fromJson(json['location'] as Map<String, dynamic>),
      saltedVectorHash: json['saltedVectorHash'] as String,
      previousMeetingHash: json['previousMeetingHash'] as String,
      signatures: (json['signatures'] as List<dynamic>)
          .map((s) => ParticipantSignature.fromJson(s as Map<String, dynamic>))
          .toList(),
      ipfsCid: json['ipfsCid'] as String?,
    );
  }

  MeetingProof copyWith({
    String? timestamp,
    LocationPoint? location,
    String? saltedVectorHash,
    String? previousMeetingHash,
    List<ParticipantSignature>? signatures,
    Object? ipfsCid = _unset,
  }) {
    return MeetingProof(
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      saltedVectorHash: saltedVectorHash ?? this.saltedVectorHash,
      previousMeetingHash: previousMeetingHash ?? this.previousMeetingHash,
      signatures: signatures ?? this.signatures,
      ipfsCid: identical(ipfsCid, _unset) ? this.ipfsCid : ipfsCid as String?,
    );
  }

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

  String canonicalJson() {
    final sortedSigs = [...signatures]
      ..sort((a, b) => a.publicKeyHex.compareTo(b.publicKeyHex));
    final canonical = <String, dynamic>{
      'timestamp': timestamp,
      'location': <String, double>{
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'saltedVectorHash': saltedVectorHash,
      'previousMeetingHash': previousMeetingHash,
      'signatures': sortedSigs.map((s) => s.toJson()).toList(),
    };
    return jsonEncode(canonical);
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

const Object _unset = Object();
