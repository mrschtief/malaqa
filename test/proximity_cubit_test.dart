import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/core/interfaces/crypto_provider.dart';
import 'package:malaqa/domain/entities/face_vector.dart';
import 'package:malaqa/domain/entities/location_point.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/entities/participant_signature.dart';
import 'package:malaqa/domain/services/face_matcher_service.dart';
import 'package:malaqa/domain/services/meeting_handshake_service.dart';
import 'package:malaqa/domain/services/proof_importer.dart';
import 'package:malaqa/data/datasources/nearby_service.dart';
import 'package:malaqa/presentation/blocs/proximity/proximity_cubit.dart';

class FakeCryptoProvider implements CryptoProvider {
  @override
  Future<List<int>> sha256(List<int> payload) async {
    return List<int>.filled(32, payload.length % 251);
  }

  @override
  Future<List<int>> sign({
    required Object keyPairRef,
    required List<int> message,
  }) async {
    return List<int>.filled(64, message.length % 251);
  }

  @override
  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  }) async {
    return signature.isNotEmpty && publicKey.isNotEmpty;
  }

  @override
  List<int> randomBytes(int length) {
    return List<int>.generate(length, (index) => index + 1);
  }
}

class AlwaysInvalidVerifyCryptoProvider extends FakeCryptoProvider {
  @override
  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  }) async {
    return false;
  }
}

class FakeNearbyService implements NearbyService {
  final controller = StreamController<NearbyPayloadEvent>.broadcast();
  final List<String> sentPayloads = <String>[];

  bool startedDiscovery = false;
  bool startedAdvertising = false;
  bool failDiscoveryWithPermission = false;
  String? lastAdvertisingPayload;

  @override
  Stream<NearbyPayloadEvent> get payloadStream => controller.stream;

  @override
  Future<void> startAdvertising({
    required String userName,
    required String payload,
  }) async {
    startedAdvertising = true;
    lastAdvertisingPayload = payload;
  }

  @override
  Future<void> startDiscovery({
    required String userName,
  }) async {
    if (failDiscoveryWithPermission) {
      throw Exception('Permission denied for nearby discovery');
    }
    startedDiscovery = true;
  }

  @override
  Future<void> sendPayload({
    required String endpointId,
    required String payload,
  }) async {
    sentPayloads.add(payload);
  }

  @override
  Future<void> stopAll() async {}

  Future<void> emitPayload(
    String payload, {
    String endpointId = 'endpoint-1',
  }) async {
    controller.add(
      NearbyPayloadEvent(endpointId: endpointId, payload: payload),
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

Future<MeetingProof> _ownerSignedDraft({
  required CryptoProvider crypto,
  required Identity owner,
}) async {
  final handshake = MeetingHandshakeService(crypto);
  final draft = await handshake.createDraftProof(
    vectorA: FaceVector(const [1.0, 0.0, 0.0]),
    vectorB: FaceVector(const [0.0, 1.0, 0.0]),
    location: const LocationPoint(latitude: 52.52, longitude: 13.405),
    previousMeetingHash: '0000',
    timestamp: DateTime.utc(2026, 2, 14, 20),
  );
  final ownerSig = await handshake.signProofPayload(
    participant: owner,
    proof: draft,
  );
  return draft.copyWith(signatures: <ParticipantSignature>[ownerSig]);
}

void main() {
  test('ProximityCubit emits match found when payload matches owner vector',
      () async {
    final nearby = FakeNearbyService();
    final identity = await Identity.create(name: 'Bob');
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: FakeCryptoProvider(),
      matchThreshold: 0.8,
    );

    await cubit.setAuthenticated(
      userName: 'Bob',
      identity: identity,
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
    final identity = await Identity.create(name: 'Bob');
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: FakeCryptoProvider(),
      matchThreshold: 0.8,
    );

    await cubit.setAuthenticated(
      userName: 'Bob',
      identity: identity,
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

  test('ProximityCubit emits permission error when discovery permission fails',
      () async {
    final nearby = FakeNearbyService()..failDiscoveryWithPermission = true;
    final identity = await Identity.create(name: 'Bob');
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: FakeCryptoProvider(),
      matchThreshold: 0.8,
    );

    await cubit.setAuthenticated(
      userName: 'Bob',
      identity: identity,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    expect(cubit.state, isA<ProximityPermissionError>());

    await cubit.close();
    await nearby.dispose();
  });

  test('requestGuestSignature resolves with response payload', () async {
    final nearby = FakeNearbyService();
    final crypto = FakeCryptoProvider();
    final owner = await Identity.create(name: 'Owner');
    final guest = await Identity.create(name: 'Guest');
    final draft = await _ownerSignedDraft(
      crypto: crypto,
      owner: owner,
    );
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: crypto,
      matchThreshold: 0.8,
    );
    await cubit.setAuthenticated(
      userName: owner.name,
      identity: owner,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final requestFuture = cubit.requestGuestSignature(
      draftProof: draft,
      guestVector: FaceVector(const [1.0, 0.0, 0.0]),
      timeout: const Duration(seconds: 1),
    );

    await Future<void>.delayed(Duration.zero);
    final requestJson =
        jsonDecode(nearby.lastAdvertisingPayload!) as Map<String, dynamic>;
    final requestId = requestJson['requestId'] as String;
    final payloadToSign = (requestJson['proof'] as Map<String, dynamic>);
    final requestProof = MeetingProof.fromJson(payloadToSign);
    final guestSignature =
        await MeetingHandshakeService(crypto).signProofPayload(
      participant: guest,
      proof: requestProof,
    );
    final response = jsonEncode({
      'type': 'meeting_sign_response_v1',
      'requestId': requestId,
      'signature': guestSignature.toJson(),
    });
    await nearby.emitPayload(response);

    final resolved = await requestFuture;
    expect(resolved, isNotNull);
    expect(resolved!.publicKeyHex, guest.publicKeyHex);

    await cubit.close();
    await nearby.dispose();
  });

  test('requestGuestSignature returns null when request is rejected', () async {
    final nearby = FakeNearbyService();
    final crypto = FakeCryptoProvider();
    final owner = await Identity.create(name: 'Owner');
    final draft = await _ownerSignedDraft(
      crypto: crypto,
      owner: owner,
    );
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: crypto,
      matchThreshold: 0.8,
    );
    await cubit.setAuthenticated(
      userName: owner.name,
      identity: owner,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final requestFuture = cubit.requestGuestSignature(
      draftProof: draft,
      guestVector: FaceVector(const [1.0, 0.0, 0.0]),
      timeout: const Duration(seconds: 1),
    );

    await Future<void>.delayed(Duration.zero);
    final requestJson =
        jsonDecode(nearby.lastAdvertisingPayload!) as Map<String, dynamic>;
    final requestId = requestJson['requestId'] as String;
    final reject = jsonEncode({
      'type': 'meeting_sign_reject_v1',
      'requestId': requestId,
      'reason': 'face-mismatch',
    });
    await nearby.emitPayload(reject);

    final resolved = await requestFuture;
    expect(resolved, isNull);

    await cubit.close();
    await nearby.dispose();
  });

  test('requestGuestSignature returns null on timeout', () async {
    final nearby = FakeNearbyService();
    final crypto = FakeCryptoProvider();
    final owner = await Identity.create(name: 'Owner');
    final draft = await _ownerSignedDraft(
      crypto: crypto,
      owner: owner,
    );
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: crypto,
      matchThreshold: 0.8,
      signatureRequestTimeout: const Duration(milliseconds: 50),
    );
    await cubit.setAuthenticated(
      userName: owner.name,
      identity: owner,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final resolved = await cubit.requestGuestSignature(
      draftProof: draft,
      guestVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    expect(resolved, isNull);

    await cubit.close();
    await nearby.dispose();
  });

  test('requestGuestSignature ignores response with mismatched request id',
      () async {
    final nearby = FakeNearbyService();
    final crypto = FakeCryptoProvider();
    final owner = await Identity.create(name: 'Owner');
    final draft = await _ownerSignedDraft(
      crypto: crypto,
      owner: owner,
    );
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: crypto,
      matchThreshold: 0.8,
      signatureRequestTimeout: const Duration(milliseconds: 80),
    );
    await cubit.setAuthenticated(
      userName: owner.name,
      identity: owner,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final requestFuture = cubit.requestGuestSignature(
      draftProof: draft,
      guestVector: FaceVector(const [1.0, 0.0, 0.0]),
    );
    await Future<void>.delayed(Duration.zero);
    final requestJson =
        jsonDecode(nearby.lastAdvertisingPayload!) as Map<String, dynamic>;
    final wrongResponse = jsonEncode({
      'type': 'meeting_sign_response_v1',
      'requestId': '${requestJson['requestId']}-other',
      'signature': {
        'publicKeyHex': owner.publicKeyHex,
        'signatureHex': 'aa',
      },
    });
    await nearby.emitPayload(wrongResponse);

    final resolved = await requestFuture;
    expect(resolved, isNull);

    await cubit.close();
    await nearby.dispose();
  });

  test('incoming sign request sends reject on face mismatch', () async {
    final nearby = FakeNearbyService();
    final crypto = FakeCryptoProvider();
    final owner = await Identity.create(name: 'Owner');
    final initiator = await Identity.create(name: 'Initiator');
    final draft = await _ownerSignedDraft(
      crypto: crypto,
      owner: initiator,
    );
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: crypto,
      matchThreshold: 0.8,
    );
    await cubit.setAuthenticated(
      userName: owner.name,
      identity: owner,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final request = jsonEncode({
      'type': 'meeting_sign_request_v1',
      'requestId': 'req-1',
      'proof': draft.toJson(),
      'guestVector': const [0.0, 1.0, 0.0],
    });
    await nearby.emitPayload(request, endpointId: 'endpoint-z');

    expect(nearby.sentPayloads, isNotEmpty);
    final sent = jsonDecode(nearby.sentPayloads.last) as Map<String, dynamic>;
    expect(sent['type'], 'meeting_sign_reject_v1');
    expect(sent['requestId'], 'req-1');

    await cubit.close();
    await nearby.dispose();
  });

  test('incoming sign request rejects invalid initiator signature', () async {
    final nearby = FakeNearbyService();
    final owner = await Identity.create(name: 'Owner');
    final initiator = await Identity.create(name: 'Initiator');
    final draft = await _ownerSignedDraft(
      crypto: FakeCryptoProvider(),
      owner: initiator,
    );
    final cubit = ProximityCubit(
      nearbyService: nearby,
      proofImporter: FakeProofImporter(),
      faceMatcher: FaceMatcherService(),
      crypto: AlwaysInvalidVerifyCryptoProvider(),
      matchThreshold: 0.8,
    );
    await cubit.setAuthenticated(
      userName: owner.name,
      identity: owner,
      ownerVector: FaceVector(const [1.0, 0.0, 0.0]),
    );

    final request = jsonEncode({
      'type': 'meeting_sign_request_v1',
      'requestId': 'req-invalid-sig',
      'proof': draft.toJson(),
      'guestVector': const [1.0, 0.0, 0.0],
    });
    await nearby.emitPayload(request, endpointId: 'endpoint-x');

    expect(nearby.sentPayloads, isNotEmpty);
    final sent = jsonDecode(nearby.sentPayloads.last) as Map<String, dynamic>;
    expect(sent['type'], 'meeting_sign_reject_v1');
    expect(sent['requestId'], 'req-invalid-sig');
    expect(sent['reason'], 'invalid-initiator-signature');

    await cubit.close();
    await nearby.dispose();
  });
}
