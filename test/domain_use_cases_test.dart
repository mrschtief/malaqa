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
  late CreateMeetingProofUseCase createProofUseCase;
  late VerifyMeetingProofUseCase verifyProofUseCase;
  late ValidateChainUseCase validateChainUseCase;

  setUp(() {
    crypto = Ed25519CryptoProvider();
    handshake = MeetingHandshakeService(crypto);
    chainManager = ChainManager(crypto);
    createProofUseCase = CreateMeetingProofUseCase(handshake);
    verifyProofUseCase = VerifyMeetingProofUseCase(crypto);
    validateChainUseCase = ValidateChainUseCase(chainManager);
  });

  test('CreateMeetingProofUseCase creates a valid proof', () async {
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final proof = await createProofUseCase.execute(
      CreateMeetingProofInput(
        participantA: alice,
        participantB: bob,
        vectorA: FaceVector(vectorFor(101)),
        vectorB: FaceVector(vectorFor(102)),
        location: const LocationPoint(latitude: 48.8566, longitude: 2.3522),
        previousMeetingHash: '0000',
        timestamp: DateTime.utc(2026, 2, 14, 16, 0, 0),
      ),
    );

    expect(proof.previousMeetingHash, equals('0000'));
    expect(proof.signatures.length, equals(2));
    expect(await verifyProofUseCase.execute(proof), isTrue);
  });

  test('VerifyMeetingProofUseCase rejects tampered data', () async {
    final alice = await Identity.create(name: 'Alice');
    final bob = await Identity.create(name: 'Bob');

    final proof = await createProofUseCase.execute(
      CreateMeetingProofInput(
        participantA: alice,
        participantB: bob,
        vectorA: FaceVector(vectorFor(201)),
        vectorB: FaceVector(vectorFor(202)),
        location: const LocationPoint(latitude: 51.5074, longitude: -0.1278),
        previousMeetingHash: '0000',
        timestamp: DateTime.utc(2026, 2, 14, 16, 5, 0),
      ),
    );

    final tampered = MeetingProof(
      timestamp: proof.timestamp,
      location: const LocationPoint(latitude: 52.0, longitude: -0.1278),
      saltedVectorHash: proof.saltedVectorHash,
      previousMeetingHash: proof.previousMeetingHash,
      signatures: proof.signatures,
    );

    expect(await verifyProofUseCase.execute(tampered), isFalse);
  });

  test('ValidateChainUseCase validates a linked chain', () async {
    final people = <Identity>[
      await Identity.create(name: 'Alice'),
      await Identity.create(name: 'Bob'),
      await Identity.create(name: 'Charlie'),
      await Identity.create(name: 'Diana'),
    ];

    final proofs = <MeetingProof>[];
    var previousHash = '0000';

    for (var i = 0; i < people.length - 1; i++) {
      final proof = await createProofUseCase.execute(
        CreateMeetingProofInput(
          participantA: people[i],
          participantB: people[i + 1],
          vectorA: FaceVector(vectorFor(i + 300)),
          vectorB: FaceVector(vectorFor(i + 301)),
          location: LocationPoint(
            latitude: 30 + i.toDouble(),
            longitude: 40 + i.toDouble(),
          ),
          previousMeetingHash: previousHash,
          timestamp: DateTime.utc(2026, 2, 14, 16, i, 0),
        ),
      );
      proofs.add(proof);
      previousHash = await proof.computeProofHash(crypto);
    }

    expect(await validateChainUseCase.execute(proofs), isTrue);

    final broken = [...proofs];
    broken[1] = MeetingProof(
      timestamp: broken[1].timestamp,
      location: broken[1].location,
      saltedVectorHash: broken[1].saltedVectorHash,
      previousMeetingHash: 'deadbeef',
      signatures: broken[1].signatures,
    );
    expect(await validateChainUseCase.execute(broken), isFalse);
  });
}
