import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/entities/meeting_signature_exchange.dart';
import 'package:malaqa/domain/entities/participant_signature.dart';

void main() {
  final proof = MeetingProof(
    timestamp: DateTime.utc(2026, 2, 17, 10).toIso8601String(),
    location: const LocationPoint(latitude: 52.52, longitude: 13.405),
    saltedVectorHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    previousMeetingHash: '0000',
    signatures: const [
      ParticipantSignature(
        publicKeyHex: 'a1',
        signatureHex: 'b2',
      ),
    ],
  );

  test('request envelope roundtrip', () {
    final request = MeetingSignRequestEnvelope(
      requestId: 'req-1',
      proof: proof,
      guestVectorValues: const [1, 0, 0],
    );
    final raw = jsonEncode(request.toJson());

    final parsed = MeetingSignRequestEnvelope.tryParseRaw(raw);
    expect(parsed, isNotNull);
    expect(parsed!.requestId, 'req-1');
    expect(parsed.guestVectorValues, hasLength(3));
    expect(parsed.proof.signatures, hasLength(1));
  });

  test('response envelope roundtrip', () {
    final response = MeetingSignResponseEnvelope(
      requestId: 'req-2',
      signature: const ParticipantSignature(
        publicKeyHex: 'abc',
        signatureHex: 'def',
      ),
    );
    final raw = jsonEncode(response.toJson());

    final parsed = MeetingSignResponseEnvelope.tryParseRaw(raw);
    expect(parsed, isNotNull);
    expect(parsed!.requestId, 'req-2');
    expect(parsed.signature.publicKeyHex, 'abc');
  });

  test('reject envelope roundtrip', () {
    final reject = MeetingSignRejectEnvelope(
      requestId: 'req-3',
      reason: 'face-mismatch',
    );
    final raw = jsonEncode(reject.toJson());

    final parsed = MeetingSignRejectEnvelope.tryParseRaw(raw);
    expect(parsed, isNotNull);
    expect(parsed!.requestId, 'req-3');
    expect(parsed.reason, 'face-mismatch');
  });
}
