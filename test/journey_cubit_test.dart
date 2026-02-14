import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/repositories/chain_repository.dart';
import 'package:malaqa/presentation/blocs/journey/journey_cubit.dart';

class FakeJourneyChainRepository implements ChainRepository {
  FakeJourneyChainRepository(
      {this.proofs = const <MeetingProof>[], this.fail = false});

  final List<MeetingProof> proofs;
  final bool fail;

  @override
  Future<List<MeetingProof>> getAllProofs() async {
    if (fail) {
      throw StateError('db failure');
    }
    return proofs;
  }

  @override
  Future<MeetingProof?> getLatestProof() async {
    if (proofs.isEmpty) {
      return null;
    }
    return proofs.last;
  }

  @override
  Future<void> saveProof(MeetingProof proof) async {}
}

MeetingProof proofAt(DateTime timestamp) {
  return MeetingProof(
    timestamp: timestamp.toUtc().toIso8601String(),
    location: const LocationPoint(latitude: 0, longitude: 0),
    saltedVectorHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    previousMeetingHash: '0000',
    signatures: const [],
  );
}

void main() {
  test('JourneyCubit emits empty state when no proofs exist', () async {
    final cubit = JourneyCubit(FakeJourneyChainRepository());

    await cubit.loadJourney();

    expect(cubit.state, isA<JourneyEmpty>());
    await cubit.close();
  });

  test('JourneyCubit emits loaded state in reverse chronological order',
      () async {
    final oldProof = proofAt(DateTime.utc(2026, 2, 10, 12));
    final newProof = proofAt(DateTime.utc(2026, 2, 12, 18));
    final cubit = JourneyCubit(
      FakeJourneyChainRepository(
        proofs: <MeetingProof>[oldProof, newProof],
      ),
    );

    await cubit.loadJourney();

    expect(cubit.state, isA<JourneyLoaded>());
    final loaded = cubit.state as JourneyLoaded;
    expect(loaded.proofs.first.timestamp, equals(newProof.timestamp));
    expect(loaded.proofs.last.timestamp, equals(oldProof.timestamp));
    await cubit.close();
  });

  test('JourneyCubit emits error state when repository fails', () async {
    final cubit = JourneyCubit(FakeJourneyChainRepository(fail: true));

    await cubit.loadJourney();

    expect(cubit.state, isA<JourneyError>());
    await cubit.close();
  });
}
