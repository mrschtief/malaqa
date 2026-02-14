import 'package:malaqa/malaqa.dart';

List<double> vectorFor(int seed) {
  return List<double>.generate(
    512,
    (i) => ((seed + 1) * (i + 1)) / 1000.0,
  );
}

Future<void> main() async {
  final crypto = Ed25519CryptoProvider();
  final handshake = MeetingHandshakeService(crypto);
  final chainManager = ChainManager(crypto);

  final alice = await Identity.create(name: 'Alice');
  final bob = await Identity.create(name: 'Bob');
  final charlie = await Identity.create(name: 'Charlie');

  final firstProof = await handshake.createProof(
    participantA: alice,
    participantB: bob,
    vectorA: FaceVector(vectorFor(1)),
    vectorB: FaceVector(vectorFor(2)),
    location: const LocationPoint(latitude: 48.137154, longitude: 11.576124),
    previousMeetingHash: '0000',
  );
  chainManager.addProof(firstProof);

  final firstHash = await firstProof.computeProofHash(crypto);

  final secondProof = await handshake.createProof(
    participantA: bob,
    participantB: charlie,
    vectorA: FaceVector(vectorFor(2)),
    vectorB: FaceVector(vectorFor(3)),
    location: const LocationPoint(latitude: 35.6895, longitude: 139.6917),
    previousMeetingHash: firstHash,
  );
  chainManager.addProof(secondProof);

  final chainValid = await chainManager.isValidChain(chainManager.chain);
  print('Chain valid: $chainValid');
  print('Meetings in chain: ${chainManager.chain.length}');
}
