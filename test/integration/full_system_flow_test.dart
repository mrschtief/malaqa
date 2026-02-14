import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:malaqa/core/utils/app_logger.dart';
import 'package:malaqa/malaqa.dart';

import '../mocks/headless_mocks.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value.toDouble();

  @override
  int nextInt(int max) => value % max;
}

class _DummyCameraImage implements CameraImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCameraScanner
    implements BiometricScanner<BiometricScanRequest<CameraImage>> {
  _FakeCameraScanner({required this.vectors});

  final List<FaceVector> vectors;

  @override
  Future<FaceVector?> captureFace(
    BiometricScanRequest<CameraImage> input,
  ) async {
    if (vectors.isEmpty) {
      return null;
    }
    return vectors.first;
  }

  @override
  Future<List<FaceVector>> scanFaces(
    BiometricScanRequest<CameraImage> input,
    List<FaceBounds> allFaces,
  ) async {
    return vectors;
  }
}

class _FakeNearbyService implements NearbyService {
  final StreamController<NearbyPayloadEvent> _controller =
      StreamController<NearbyPayloadEvent>.broadcast();

  @override
  Stream<NearbyPayloadEvent> get payloadStream => _controller.stream;

  @override
  Future<void> startAdvertising({
    required String userName,
    required String payload,
  }) async {}

  @override
  Future<void> startDiscovery({
    required String userName,
  }) async {}

  @override
  Future<void> stopAll() async {}

  Future<void> emitPayload(String payload) async {
    _controller.add(
      NearbyPayloadEvent(endpointId: 'endpoint-A', payload: payload),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var isarAvailable = true;

  setUpAll(() async {
    try {
      await Isar.initializeIsarCore(download: true);
    } catch (_) {
      isarAvailable = false;
    }
  });

  test('Malaqa full lifecycle validates Auth -> P2P -> DB -> Map -> Profile',
      () async {
    if (!isarAvailable) {
      return;
    }

    AppLogger.clear();
    final tmpDir = await Directory.systemTemp.createTemp('malaqa_full_flow_');
    final dbName = 'malaqa_full_${DateTime.now().microsecondsSinceEpoch}';
    Isar? isar;
    _FakeNearbyService? nearbyService;
    AuthCubit? authCubit;
    ProximityCubit? proximityCubit;
    MapCubit? initialMapCubit;
    MapCubit? updatedMapCubit;
    ProfileCubit? profileCubit;

    try {
      isar = await Isar.open(
        [MeetingProofModelSchema],
        directory: tmpDir.path,
        name: dbName,
        inspector: false,
      );

      await configureDependencies(
        reset: true,
        isarOverride: isar,
        secureStoreOverride: HeadlessSecureStore(),
      );

      final identityRepository = getIt<IdentityRepository>();
      final chainRepository = getIt<ChainRepository>();
      final handshakeService = getIt<MeetingHandshakeService>();
      final proofImporter = getIt<ProofImporter>();

      initialMapCubit = MapCubit(chainRepository);
      await initialMapCubit.loadMapData();
      expect(initialMapCubit.state, isA<MapEmpty>());

      final localIdentity = await Identity.create(name: 'Bob');
      final ownerVector = FaceVector(const [1.0, 0.0, 0.0]);
      await identityRepository.saveIdentity(localIdentity);
      await identityRepository.saveOwnerFaceVector(ownerVector);

      authCubit = AuthCubit(
        identityRepository: identityRepository,
        scanner: _FakeCameraScanner(vectors: [ownerVector]),
        faceMatcher: FaceMatcherService(),
        livenessGuard: LivenessGuard(random: _FixedRandom(0)),
        scanInterval: Duration.zero,
        matchThreshold: 0.8,
        maxFailedScans: 5,
      );

      await authCubit.checkIdentity();
      expect(authCubit.state, isA<AuthScanning>());

      await authCubit.processFrame(
        BiometricScanRequest<CameraImage>(
          image: _DummyCameraImage(),
          rotationDegrees: 0,
        ),
        const [
          FaceBounds(
            left: 0,
            top: 0,
            right: 100,
            bottom: 100,
            smilingProbability: 0.2,
            leftEyeOpenProbability: 0.9,
            rightEyeOpenProbability: 0.9,
          ),
        ],
      );
      AppLogger.log(
        'LIVENESS',
        'Challenge: Smile... Input: Neutral -> REJECTED',
      );
      expect(authCubit.state, isA<AuthScanning>());

      await authCubit.processFrame(
        BiometricScanRequest<CameraImage>(
          image: _DummyCameraImage(),
          rotationDegrees: 0,
        ),
        const [
          FaceBounds(
            left: 0,
            top: 0,
            right: 100,
            bottom: 100,
            smilingProbability: 0.95,
            leftEyeOpenProbability: 0.9,
            rightEyeOpenProbability: 0.9,
          ),
        ],
      );
      AppLogger.log('LIVENESS', 'Input: Smile -> ACCEPTED');
      expect(authCubit.state, isA<AuthAuthenticated>());

      nearbyService = _FakeNearbyService();
      proximityCubit = ProximityCubit(
        nearbyService: nearbyService,
        proofImporter: proofImporter,
        faceMatcher: FaceMatcherService(),
        matchThreshold: 0.8,
        advertisingWindow: const Duration(seconds: 30),
      );

      await proximityCubit.setAuthenticated(
        userName: localIdentity.name,
        ownerVector: ownerVector,
      );
      expect(proximityCubit.state, isA<ProximityDiscovering>());

      final remoteIdentity = await Identity.create(name: 'Alice');
      final receivedProof = await handshakeService.createProof(
        participantA: remoteIdentity,
        participantB: localIdentity,
        vectorA: FaceVector(const [0.0, 1.0, 0.0]),
        vectorB: ownerVector,
        location: const LocationPoint(latitude: 52.52, longitude: 13.405),
        previousMeetingHash: '0000',
        timestamp: DateTime.utc(2026, 2, 14, 22, 0, 0),
      );
      final transferEnvelope = jsonEncode({
        'proof': receivedProof.toJson(),
        'guestVector': ownerVector.values,
      });

      AppLogger.log('P2P', 'Payload received... Decoding...');
      await nearbyService.emitPayload(transferEnvelope);
      expect(proximityCubit.state, isA<ProximityMatchFound>());

      await proximityCubit.claimAndSave();
      expect(proximityCubit.state, isA<ProximityClaimed>());
      final claimState = proximityCubit.state as ProximityClaimed;
      expect(claimState.result.status, ImportStatus.success);

      final storedProofs = await chainRepository.getAllProofs();
      AppLogger.log('DB', 'Proof saved. Chain length: ${storedProofs.length}');
      expect(storedProofs, hasLength(1));

      updatedMapCubit = MapCubit(chainRepository);
      await updatedMapCubit.loadMapData();
      expect(updatedMapCubit.state, isA<MapLoaded>());
      final loadedMap = updatedMapCubit.state as MapLoaded;
      expect(loadedMap.markers, hasLength(1));
      expect(loadedMap.polylines, hasLength(1));
      AppLogger.log(
          'MAP', 'Updating layers... Markers: ${loadedMap.markers.length}');

      profileCubit = ProfileCubit(
        identityRepository: identityRepository,
        chainRepository: chainRepository,
        statisticsService: StatisticsService(),
        badgeManager: BadgeManager(
          statisticsService: StatisticsService(),
        ),
      );
      await profileCubit.loadProfile();
      expect(profileCubit.state, isA<ProfileLoaded>());
      final profileLoaded = profileCubit.state as ProfileLoaded;
      expect(profileLoaded.stats.meetingsCount, 1);

      for (final line in AppLogger.logs) {
        // ignore: avoid_print
        print(line);
      }
    } finally {
      await authCubit?.close();
      await proximityCubit?.close();
      await initialMapCubit?.close();
      await updatedMapCubit?.close();
      await profileCubit?.close();
      await nearbyService?.dispose();
      await getIt.reset();
      if (isar != null && isar.isOpen) {
        await isar.close(deleteFromDisk: true);
      }
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    }
  });
}
