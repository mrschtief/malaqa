import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/entities/participant_signature.dart';
import 'package:malaqa/domain/gamification/badge_definitions.dart';
import 'package:malaqa/domain/gamification/badge_manager.dart';
import 'package:malaqa/domain/services/statistics_service.dart';

MeetingProof _proof({
  required DateTime timestamp,
  required LocationPoint location,
  required List<ParticipantSignature> signatures,
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
  final badgeManager = BadgeManager(statisticsService: StatisticsService());

  test('checkUnlocks returns empty list for no proofs', () async {
    final me = await Identity.create(name: 'me');

    final unlocked = badgeManager.checkUnlocks([], me: me);

    expect(unlocked, isEmpty);
  });

  test('checkUnlocks unlocks First Contact after one meeting', () async {
    final me = await Identity.create(name: 'me');
    const guestKey =
        '1111111111111111111111111111111111111111111111111111111111111111';

    final proofs = [
      _proof(
        timestamp: DateTime.utc(2026, 2, 2, 10),
        location: const LocationPoint(latitude: 52.5200, longitude: 13.4050),
        signatures: [
          ParticipantSignature(
            publicKeyHex: me.publicKeyHex,
            signatureHex:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
          const ParticipantSignature(
            publicKeyHex: guestKey,
            signatureHex:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        ],
      ),
    ];

    final unlocked = badgeManager.checkUnlocks(proofs, me: me);

    expect(unlocked, contains(BadgeType.firstContact));
  });
}
