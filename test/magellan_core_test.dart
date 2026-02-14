import 'package:malaqa/malaqa.dart';
import 'package:test/test.dart';

List<double> vectorFor(int seed) {
  return List<double>.generate(
    512,
    (i) => ((seed + 1) * (i + 1)) / 1000.0,
  );
}

void main() {
  late Ed25519CryptoProvider crypto;
  late MeetingHandshakeService handshake;
  late ChainManager chainManager;

  setUp(() {
    crypto = Ed25519CryptoProvider();
    handshake = MeetingHandshakeService(crypto);
    chainManager = ChainManager(crypto);
  });

  test('Test 1: valid handshake between Alice and Bob verifies as true', () async {
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final proof = await handshake.createProof(
      participantA: alice,
      participantB: bob,
      vectorA: FaceVector(vectorFor(1)),
      vectorB: FaceVector(vectorFor(2)),
      location: const LocationPoint(latitude: 47.3769, longitude: 8.5417),
      previousMeetingHash: '0000',
      timestamp: DateTime.utc(2026, 2, 14, 12, 0, 0),
    );

    expect(await proof.verifyProof(crypto), isTrue);
  });

  test('Test 2: tampering timestamp or location after signing fails verification',
      () async {
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final original = await handshake.createProof(
      participantA: alice,
      participantB: bob,
      vectorA: FaceVector(vectorFor(3)),
      vectorB: FaceVector(vectorFor(4)),
      location: const LocationPoint(latitude: 40.7128, longitude: -74.0060),
      previousMeetingHash: '0000',
      timestamp: DateTime.utc(2026, 2, 14, 12, 5, 0),
    );

    final tamperedTimestamp = MeetingProof(
      timestamp: DateTime.utc(2026, 2, 14, 13, 5, 0).toIso8601String(),
      location: original.location,
      saltedVectorHash: original.saltedVectorHash,
      previousMeetingHash: original.previousMeetingHash,
      signatures: original.signatures,
    );

    final tamperedLocation = MeetingProof(
      timestamp: original.timestamp,
      location: const LocationPoint(latitude: 41.0, longitude: -74.0060),
      saltedVectorHash: original.saltedVectorHash,
      previousMeetingHash: original.previousMeetingHash,
      signatures: original.signatures,
    );

    expect(await tamperedTimestamp.verifyProof(crypto), isFalse);
    expect(await tamperedLocation.verifyProof(crypto), isFalse);
  });

  test(
      'Test 3: chain of 5 people verifies when all links reference previous hash',
      () async {
    final people = <Identity>[
      await Identity.create(name: 'Alice'),
      await Identity.create(name: 'Bob'),
      await Identity.create(name: 'Charlie'),
      await Identity.create(name: 'Diana'),
      await Identity.create(name: 'Eve'),
    ];

    final proofs = <MeetingProof>[];
    var previousHash = '0000';

    for (var i = 0; i < people.length - 1; i++) {
      final proof = await handshake.createProof(
        participantA: people[i],
        participantB: people[i + 1],
        vectorA: FaceVector(vectorFor(i + 10)),
        vectorB: FaceVector(vectorFor(i + 11)),
        location: LocationPoint(
          latitude: 10.0 + i,
          longitude: 20.0 + i,
        ),
        previousMeetingHash: previousHash,
        timestamp: DateTime.utc(2026, 2, 14, 12, i, 0),
      );
      proofs.add(proof);
      previousHash = await proof.computeProofHash(crypto);
      chainManager.addProof(proof);
    }

    expect(await chainManager.isValidChain(proofs), isTrue);
    expect(await chainManager.isValidChain(chainManager.chain), isTrue);
  });
}
