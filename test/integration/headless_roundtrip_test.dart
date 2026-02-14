import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:malaqa/core/utils/app_logger.dart';
import 'package:malaqa/malaqa.dart';

import '../mocks/headless_mocks.dart';

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

  test('Headless roundtrip validates scanner -> proof -> DB -> verify',
      () async {
    if (!isarAvailable) {
      return;
    }

    AppLogger.clear();

    final tmpDir = await Directory.systemTemp.createTemp('malaqa_headless_');
    final dbName = 'malaqa_headless_${DateTime.now().microsecondsSinceEpoch}';
    Isar? isar;

    try {
      isar = await Isar.open(
        [MeetingProofModelSchema],
        directory: tmpDir.path,
        name: dbName,
        inspector: false,
      );

      final scanner = MockBiometricScanner();
      final secureStore = HeadlessSecureStore();
      await configureDependencies(
        reset: true,
        isarOverride: isar,
        secureStoreOverride: secureStore,
      );

      final crypto = getIt<CryptoProvider>();
      final ensureIdentity = getIt<EnsureLocalIdentityUseCase>();
      final chainRepository = getIt<ChainRepository>();
      final handshakeService = getIt<MeetingHandshakeService>();
      final participantResolver = getIt<MeetingParticipantResolver>();

      final localIdentity = await ensureIdentity.execute(defaultName: 'Alice');
      expect(
        AppLogger.logs.any((line) => line.contains('Identity created')),
        isTrue,
      );

      final ownerVector = await scanner.captureFace('A');
      expect(ownerVector, isNotNull);

      final detectedVectors = await scanner.scanFaces(
        'MEETING',
        const <FaceBounds>[
          FaceBounds(left: 10, top: 10, right: 60, bottom: 60),
          FaceBounds(left: 80, top: 12, right: 130, bottom: 62),
        ],
      );
      expect(detectedVectors, hasLength(2));

      final scanResult = participantResolver.resolve(
        detectedVectors: detectedVectors,
        ownerVector: ownerVector!,
      );
      expect(scanResult.isOwnerDetected, isTrue);
      expect(scanResult.isGuestDetected, isTrue);
      expect(scanResult.owner, isNotNull);
      expect(scanResult.guest, isNotNull);

      final partnerIdentity = await Identity.create(name: 'Bob');
      final proof = await handshakeService.createProof(
        participantA: localIdentity,
        participantB: partnerIdentity,
        vectorA: scanResult.owner!,
        vectorB: scanResult.guest!,
        location: const LocationPoint(latitude: 52.52, longitude: 13.405),
        previousMeetingHash: '0000',
        timestamp: DateTime.utc(2026, 2, 14, 20, 0, 0),
      );

      expect(await proof.verifyProof(crypto), isTrue);

      await chainRepository.saveProof(proof);
      expect(
        AppLogger.logs.any((line) => line.contains('Proof saved to DB')),
        isTrue,
      );

      await isar.close();
      isar = await Isar.open(
        [MeetingProofModelSchema],
        directory: tmpDir.path,
        name: dbName,
        inspector: false,
      );

      await configureDependencies(
        reset: true,
        isarOverride: isar,
        secureStoreOverride: secureStore,
      );

      final rebootEnsureIdentity = getIt<EnsureLocalIdentityUseCase>();
      final rebootChainRepository = getIt<ChainRepository>();

      final reloadedIdentity =
          await rebootEnsureIdentity.execute(defaultName: 'Alice');
      final reloadedProofs = await rebootChainRepository.getAllProofs();
      final latestProof = await rebootChainRepository.getLatestProof();

      expect(reloadedIdentity.publicKeyHex, equals(localIdentity.publicKeyHex));
      expect(reloadedProofs, hasLength(1));
      expect(await reloadedProofs.first.verifyProof(crypto), isTrue);
      expect(latestProof, isNotNull);

      final originalHash = await proof.computeProofHash(crypto);
      final loadedHash = await reloadedProofs.first.computeProofHash(crypto);
      final latestHash = await latestProof!.computeProofHash(crypto);

      expect(loadedHash, equals(originalHash));
      expect(latestHash, equals(originalHash));

      for (final line in AppLogger.logs) {
        // ignore: avoid_print
        print(line);
      }
    } finally {
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
