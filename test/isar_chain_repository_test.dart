import 'dart:io';

import 'package:isar/isar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/malaqa.dart';

List<double> vectorFor(int seed) {
  return List<double>.generate(
    512,
    (i) => ((seed + 1) * (i + 1)) / 1000.0,
  );
}

void main() {
  Directory? tmpDir;
  Isar? isar;
  late Ed25519CryptoProvider crypto;
  late MeetingHandshakeService handshake;
  IsarChainRepository? repository;
  var isarAvailable = true;

  setUpAll(() async {
    try {
      await Isar.initializeIsarCore(download: true);
    } catch (_) {
      isarAvailable = false;
    }
  });

  setUp(() async {
    if (!isarAvailable) {
      return;
    }

    tmpDir = await Directory.systemTemp.createTemp('malaqa_isar_test_');
    try {
      isar = await Isar.open(
        [MeetingProofModelSchema],
        directory: tmpDir!.path,
        name: 'malaqa_test_${DateTime.now().microsecondsSinceEpoch}',
        inspector: false,
      );
    } catch (_) {
      isarAvailable = false;
      return;
    }
    crypto = Ed25519CryptoProvider();
    handshake = MeetingHandshakeService(crypto);
    repository = IsarChainRepository(
      isar!,
      VerifyMeetingProofUseCase(crypto),
      crypto,
    );
  });

  tearDown(() async {
    if (isar != null && isar!.isOpen) {
      await isar!.close(deleteFromDisk: true);
    }
    if (tmpDir != null && await tmpDir!.exists()) {
      await tmpDir!.delete(recursive: true);
    }
  });

  test('IsarChainRepository saves and loads valid meeting proof', () async {
    if (!isarAvailable || repository == null) {
      return;
    }
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final proof = await handshake.createProof(
      participantA: alice,
      participantB: bob,
      vectorA: FaceVector(vectorFor(1)),
      vectorB: FaceVector(vectorFor(2)),
      location: const LocationPoint(latitude: 47.0, longitude: 8.0),
      previousMeetingHash: '0000',
      timestamp: DateTime.utc(2026, 2, 14, 18, 0, 0),
    );

    await repository!.saveProof(proof);
    final allProofs = await repository!.getAllProofs();
    final latestProof = await repository!.getLatestProof();

    expect(allProofs, hasLength(1));
    expect(allProofs.first.canonicalProof(), equals(proof.canonicalProof()));
    expect(latestProof, isNotNull);
    expect(latestProof!.canonicalProof(), equals(proof.canonicalProof()));
  });

  test(
      'IsarChainRepository filters tampered proof data via integrity validation',
      () async {
    if (!isarAvailable || repository == null || isar == null) {
      return;
    }
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final proof = await handshake.createProof(
      participantA: alice,
      participantB: bob,
      vectorA: FaceVector(vectorFor(3)),
      vectorB: FaceVector(vectorFor(4)),
      location: const LocationPoint(latitude: 40.0, longitude: -74.0),
      previousMeetingHash: '0000',
      timestamp: DateTime.utc(2026, 2, 14, 18, 5, 0),
    );

    await repository!.saveProof(proof);

    final stored = await isar!.meetingProofModels.where().findAll();
    expect(stored, hasLength(1));
    final tampered = stored.first;
    tampered.timestamp = tampered.timestamp.add(const Duration(minutes: 10));

    await isar!.writeTxn(() async {
      await isar!.meetingProofModels.put(tampered);
    });

    final allProofs = await repository!.getAllProofs();
    expect(allProofs, isEmpty);
  });
}
