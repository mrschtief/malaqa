import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/entities/participant_signature.dart';
import 'package:malaqa/domain/services/statistics_service.dart';

MeetingProof _proof({
  required DateTime timestamp,
  required LocationPoint location,
  List<ParticipantSignature> signatures = const [],
}) {
  return MeetingProof(
    timestamp: timestamp.toUtc().toIso8601String(),
    location: location,
    saltedVectorHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    previousMeetingHash: '0000',
    signatures: signatures,
  );
}

void main() {
  final service = StatisticsService();

  test('calculateTotalDistance uses haversine for ordered proof locations', () {
    final berlin = _proof(
      timestamp: DateTime.utc(2026, 2, 1, 10),
      location: const LocationPoint(latitude: 52.5200, longitude: 13.4050),
    );
    final munich = _proof(
      timestamp: DateTime.utc(2026, 2, 2, 10),
      location: const LocationPoint(latitude: 48.1351, longitude: 11.5820),
    );

    final distanceKm = service.calculateTotalDistance([berlin, munich]);

    expect(distanceKm, closeTo(504, 30));
  });

  test('calculateTotalDistance treats 0,0 location as no movement', () {
    final berlin = _proof(
      timestamp: DateTime.utc(2026, 2, 1, 10),
      location: const LocationPoint(latitude: 52.5200, longitude: 13.4050),
    );
    final unknown = _proof(
      timestamp: DateTime.utc(2026, 2, 2, 10),
      location: const LocationPoint(latitude: 0, longitude: 0),
    );
    final munich = _proof(
      timestamp: DateTime.utc(2026, 2, 3, 10),
      location: const LocationPoint(latitude: 48.1351, longitude: 11.5820),
    );

    final distanceKm =
        service.calculateTotalDistance([berlin, unknown, munich]);

    expect(distanceKm, 0);
  });

  test('countUniquePeople excludes owner public key', () async {
    final me = await Identity.create(name: 'me');
    const guest1Key =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const guest2Key =
        '2222222222222222222222222222222222222222222222222222222222222222';

    final proofs = [
      _proof(
        timestamp: DateTime.utc(2026, 2, 1, 10),
        location: const LocationPoint(latitude: 0, longitude: 0),
        signatures: [
          ParticipantSignature(
            publicKeyHex: me.publicKeyHex,
            signatureHex:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
          const ParticipantSignature(
            publicKeyHex: guest1Key,
            signatureHex:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        ],
      ),
      _proof(
        timestamp: DateTime.utc(2026, 2, 2, 10),
        location: const LocationPoint(latitude: 0, longitude: 0),
        signatures: [
          ParticipantSignature(
            publicKeyHex: me.publicKeyHex,
            signatureHex:
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          ),
          const ParticipantSignature(
            publicKeyHex: guest1Key,
            signatureHex:
                'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          ),
          const ParticipantSignature(
            publicKeyHex: guest2Key,
            signatureHex:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          ),
        ],
      ),
    ];

    final unique = service.countUniquePeople(proofs, me);

    expect(unique, 2);
  });
}
