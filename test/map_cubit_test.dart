import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/repositories/chain_repository.dart';
import 'package:malaqa/presentation/blocs/map/map_cubit.dart';

class FakeMapChainRepository implements ChainRepository {
  FakeMapChainRepository({
    this.proofs = const <MeetingProof>[],
    this.fail = false,
  });

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

MeetingProof _proof({
  required DateTime timestamp,
  required LocationPoint location,
}) {
  return MeetingProof(
    timestamp: timestamp.toUtc().toIso8601String(),
    location: location,
    saltedVectorHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    previousMeetingHash: '0000',
    signatures: const [],
  );
}

void main() {
  test('MapCubit transforms valid proofs into markers and one polyline',
      () async {
    final berlin = _proof(
      timestamp: DateTime.utc(2026, 2, 10, 10),
      location: const LocationPoint(latitude: 52.5200, longitude: 13.4050),
    );
    final paris = _proof(
      timestamp: DateTime.utc(2026, 2, 11, 10),
      location: const LocationPoint(latitude: 48.8566, longitude: 2.3522),
    );
    final london = _proof(
      timestamp: DateTime.utc(2026, 2, 12, 10),
      location: const LocationPoint(latitude: 51.5074, longitude: -0.1278),
    );
    final invalid = _proof(
      timestamp: DateTime.utc(2026, 2, 9, 10),
      location: const LocationPoint(latitude: 0, longitude: 0),
    );

    final cubit = MapCubit(
      FakeMapChainRepository(
        proofs: [berlin, invalid, paris, london],
      ),
    );

    await cubit.loadMapData();

    expect(cubit.state, isA<MapLoaded>());
    final loaded = cubit.state as MapLoaded;
    expect(loaded.markers.length, 3);
    expect(loaded.polylines.length, 1);
    expect(loaded.polylines.first.points.length, 3);
    expect(loaded.markers.first.isStart, isTrue);
    expect(loaded.centerPoint.latitude, closeTo(51.5074, 0.0001));
    expect(loaded.centerPoint.longitude, closeTo(-0.1278, 0.0001));
    await cubit.close();
  });

  test('MapCubit emits empty when only invalid coordinates exist', () async {
    final invalidOnly = _proof(
      timestamp: DateTime.utc(2026, 2, 10, 10),
      location: const LocationPoint(latitude: 0, longitude: 0),
    );

    final cubit = MapCubit(
      FakeMapChainRepository(
        proofs: [invalidOnly],
      ),
    );

    await cubit.loadMapData();

    expect(cubit.state, isA<MapEmpty>());
    await cubit.close();
  });
}
