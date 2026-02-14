import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/domain/entities/face_vector.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/services/face_matcher_service.dart';
import 'package:malaqa/domain/services/proof_importer.dart';
import 'package:malaqa/data/datasources/nearby_service.dart';
import 'package:malaqa/presentation/blocs/proximity/proximity_cubit.dart';

class FakeNearbyService implements NearbyService {
  final controller = StreamController<NearbyPayloadEvent>.broadcast();

  bool startedDiscovery = false;
  bool startedAdvertising = false;

  @override
  Stream<NearbyPayloadEvent> get payloadStream => controller.stream;

  @override
  Future<void> startAdvertising({
    required String userName,
    required String payload,
  }) async {
    startedAdvertising = true;
  }

  @override
  Future<void> startDiscovery({
    required String userName,
  }) async {
    startedDiscovery = true;
  }

  @override
  Future<void> stopAll() async {}

  Future<void> emitPayload(String payload) async {
    controller.add(
      NearbyPayloadEvent(endpointId: 'endpoint-1', payload: payload),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() => controller.close();
}

class FakeProofImporter implements ProofImporter {
  @override
  Future<ImportResult> importProof(String jsonPayload) async {
    return const ImportResult(
      status: ImportStatus.success,
      message: 'ok',
    );
  }
}

MeetingProof _proof() {
  return MeetingProof(
    timestamp: DateTime.utc(2026, 2, 14, 20).toIso8601String(),
    location: const LocationPoint(latitude: 52.52, longitude: 13.405),
    saltedVectorHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    previousMeetingHash: '0000',
    signatures: const [],
  );
}

void main() {
  test('ProximityCubit emits match found when payload matches owner vector',
      () async {
    final nearby = FakeNearbyService();
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      matchThreshold: 0.8,
    );

    await cubit.setAuthenticated(
      userName: 'Bob',
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );
    expect(cubit.state, isA<ProximityDiscovering>());

    final payload = jsonEncode({
      'proof': _proof().toJson(),
      'guestVector': const [1.0, 0.0, 0.0],
    });
    await nearby.emitPayload(payload);

    expect(cubit.state, isA<ProximityMatchFound>());

    await cubit.close();
    await nearby.dispose();
  });

  test('ProximityCubit ignores payload when face does not match', () async {
    final nearby = FakeNearbyService();
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      matchThreshold: 0.8,
    );

    await cubit.setAuthenticated(
      userName: 'Bob',
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final payload = jsonEncode({
      'proof': _proof().toJson(),
      'guestVector': const [0.0, 1.0, 0.0],
    });
    await nearby.emitPayload(payload);

    expect(cubit.state, isA<ProximityDiscovering>());

    await cubit.close();
    await nearby.dispose();
  });
}
