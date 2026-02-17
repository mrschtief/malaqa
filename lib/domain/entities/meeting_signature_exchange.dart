import 'dart:convert';

import 'meeting_proof.dart';
import 'participant_signature.dart';

const String meetingSignRequestType = 'meeting_sign_request_v1';
const String meetingSignResponseType = 'meeting_sign_response_v1';
const String meetingSignRejectType = 'meeting_sign_reject_v1';

class MeetingSignRequestEnvelope {
  const MeetingSignRequestEnvelope({
    required this.requestId,
    required this.proof,
    required this.guestVectorValues,
  });

  final String requestId;
  final MeetingProof proof;
  final List<double> guestVectorValues;

  Map<String, dynamic> toJson() {
    return {
      'type': meetingSignRequestType,
      'requestId': requestId,
      'proof': proof.toJson(),
      'guestVector': guestVectorValues,
    };
  }

  static MeetingSignRequestEnvelope? tryParseRaw(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return tryParse(decoded);
    } catch (_) {
      return null;
    }
  }

  static MeetingSignRequestEnvelope? tryParse(Map<String, dynamic> decoded) {
    try {
      if (decoded['type'] != meetingSignRequestType) {
        return null;
      }
      final requestId = decoded['requestId'] as String?;
      final proofJson = decoded['proof'];
      final guestVectorJson = decoded['guestVector'];
      if (requestId == null ||
          proofJson is! Map<String, dynamic> ||
          guestVectorJson is! List) {
        return null;
      }
      final vectorValues = guestVectorJson
          .map((value) => (value as num).toDouble())
          .toList(growable: false);
      if (vectorValues.isEmpty) {
        return null;
      }
      return MeetingSignRequestEnvelope(
        requestId: requestId,
        proof: MeetingProof.fromJson(proofJson),
        guestVectorValues: vectorValues,
      );
    } catch (_) {
      return null;
    }
  }
}

class MeetingSignResponseEnvelope {
  const MeetingSignResponseEnvelope({
    required this.requestId,
    required this.signature,
  });

  final String requestId;
  final ParticipantSignature signature;

  Map<String, dynamic> toJson() {
    return {
      'type': meetingSignResponseType,
      'requestId': requestId,
      'signature': signature.toJson(),
    };
  }

  static MeetingSignResponseEnvelope? tryParseRaw(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return tryParse(decoded);
    } catch (_) {
      return null;
    }
  }

  static MeetingSignResponseEnvelope? tryParse(Map<String, dynamic> decoded) {
    try {
      if (decoded['type'] != meetingSignResponseType) {
        return null;
      }
      final requestId = decoded['requestId'] as String?;
      final signatureJson = decoded['signature'];
      if (requestId == null || signatureJson is! Map<String, dynamic>) {
        return null;
      }
      return MeetingSignResponseEnvelope(
        requestId: requestId,
        signature: ParticipantSignature.fromJson(signatureJson),
      );
    } catch (_) {
      return null;
    }
  }
}

class MeetingSignRejectEnvelope {
  const MeetingSignRejectEnvelope({
    required this.requestId,
    required this.reason,
  });

  final String requestId;
  final String reason;

  Map<String, dynamic> toJson() {
    return {
      'type': meetingSignRejectType,
      'requestId': requestId,
      'reason': reason,
    };
  }

  static MeetingSignRejectEnvelope? tryParseRaw(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return tryParse(decoded);
    } catch (_) {
      return null;
    }
  }

  static MeetingSignRejectEnvelope? tryParse(Map<String, dynamic> decoded) {
    final type = decoded['type'];
    if (type != meetingSignRejectType) {
      return null;
    }
    final requestId = decoded['requestId'] as String?;
    final reason = decoded['reason'] as String?;
    if (requestId == null || reason == null) {
      return null;
    }
    return MeetingSignRejectEnvelope(
      requestId: requestId,
      reason: reason,
    );
  }
}
