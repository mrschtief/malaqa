import 'dart:convert';

import 'package:isar/isar.dart';

import '../../domain/entities/location_point.dart';
import '../../domain/entities/meeting_proof.dart';
import '../../domain/entities/participant_signature.dart';

part 'meeting_proof_model.g.dart';

@collection
class MeetingProofModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String proofHash;

  late DateTime timestamp;
  late double latitude;
  late double longitude;
  late String saltedVectorHash;
  late String previousMeetingHash;
  late String signaturesJson;
  String? ipfsCid;

  static MeetingProofModel fromDomain(
    MeetingProof proof, {
    required String proofHash,
  }) {
    final model = MeetingProofModel();
    model.proofHash = proofHash;
    model.timestamp = DateTime.parse(proof.timestamp).toUtc();
    model.latitude = proof.location.latitude;
    model.longitude = proof.location.longitude;
    model.saltedVectorHash = proof.saltedVectorHash;
    model.previousMeetingHash = proof.previousMeetingHash;
    model.signaturesJson = jsonEncode(
      proof.signatures.map((signature) => signature.toJson()).toList(),
    );
    model.ipfsCid = proof.ipfsCid;
    return model;
  }

  MeetingProof toDomain() {
    final signaturesRaw = jsonDecode(signaturesJson) as List<dynamic>;
    final signatures = signaturesRaw
        .map(
          (signature) =>
              ParticipantSignature.fromJson(signature as Map<String, dynamic>),
        )
        .toList();

    return MeetingProof(
      timestamp: timestamp.toUtc().toIso8601String(),
      location: LocationPoint(latitude: latitude, longitude: longitude),
      saltedVectorHash: saltedVectorHash,
      previousMeetingHash: previousMeetingHash,
      signatures: signatures,
      ipfsCid: ipfsCid,
    );
  }
}
