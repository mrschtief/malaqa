import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/malaqa.dart';

List<double> _vectorFor(int seed) {
  return List<double>.generate(
    512,
    (i) => ((seed + 1) * (i + 1)) / 1000.0,
  );
}

class _InMemoryChainRepository implements ChainRepository {
  final Map<String, MeetingProof> _proofs = <String, MeetingProof>{};

  @override
  Future<List<MeetingProof>> getAllProofs() async {
    final proofs = _proofs.values.toList(growable: false);
    proofs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return proofs;
  }

  @override
  Future<MeetingProof?> getLatestProof() async {
    final all = await getAllProofs();
    if (all.isEmpty) {
      return null;
    }
    return all.last;
  }

  @override
  Future<void> saveProof(MeetingProof proof) async {
    _proofs[proof.canonicalProof()] = proof;
  }
}

class _FakeIpfsRepository implements IpfsRepository {
  _FakeIpfsRepository({
    required this.cids,
    this.throwOnUpload = false,
  });

  final List<String> cids;
  final bool throwOnUpload;
  int _index = 0;

  @override
  Future<String> uploadProof(MeetingProof proof) async {
    if (throwOnUpload) {
      throw const IpfsUploadException('simulated upload failure');
    }

    final cid = cids[_index % cids.length];
    _index += 1;
    return cid;
  }
}

Future<MeetingProof> _createProof({
  required int seed,
  required DateTime timestamp,
  String? ipfsCid,
}) async {
  final crypto = Ed25519CryptoProvider();
  final handshake = MeetingHandshakeService(crypto);
  final alice = await Identity.create(name: 'Alice-$seed');
  final bob = await Identity.create(name: 'Bob-$seed');
  final created = await handshake.createProof(
    participantA: alice,
    participantB: bob,
    vectorA: FaceVector(_vectorFor(seed)),
    vectorB: FaceVector(_vectorFor(seed + 1)),
    location: LocationPoint(
      latitude: 48.0 + seed,
      longitude: 11.0 + seed,
    ),
    previousMeetingHash: seed == 0
        ? '0000'
        : 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    timestamp: timestamp,
  );

  return created.copyWith(ipfsCid: ipfsCid);
}

void main() {
  test('syncPendingProofs uploads unsynced proofs and stores returned CIDs',
      () async {
    final chainRepository = _InMemoryChainRepository();

    final syncedProof = await _createProof(
      seed: 0,
      timestamp: DateTime.utc(2026, 2, 14, 10, 0, 0),
      ipfsCid: 'bafyalreadysynced',
    );
    final pendingProof = await _createProof(
      seed: 1,
      timestamp: DateTime.utc(2026, 2, 14, 11, 0, 0),
    );

    await chainRepository.saveProof(syncedProof);
    await chainRepository.saveProof(pendingProof);

    final service = DecentralizedSyncService(
      chainRepository: chainRepository,
      ipfsRepository: _FakeIpfsRepository(cids: ['bafynewcid123']),
    );

    final result = await service.syncPendingProofs();
    final proofs = await chainRepository.getAllProofs();

    expect(result.pendingCount, 1);
    expect(result.syncedCount, 1);
    expect(result.failedCount, 0);
    expect(proofs.where((p) => p.ipfsCid == 'bafynewcid123').length, 1);
    expect(proofs.where((p) => p.ipfsCid == 'bafyalreadysynced').length, 1);
  });

  test('syncPendingProofs reports failures and keeps unsynced proof unchanged',
      () async {
    final chainRepository = _InMemoryChainRepository();

    final pendingProof = await _createProof(
      seed: 3,
      timestamp: DateTime.utc(2026, 2, 14, 12, 0, 0),
    );
    await chainRepository.saveProof(pendingProof);

    final service = DecentralizedSyncService(
      chainRepository: chainRepository,
      ipfsRepository: _FakeIpfsRepository(
        cids: const ['unused'],
        throwOnUpload: true,
      ),
    );

    final result = await service.syncPendingProofs();
    final proofs = await chainRepository.getAllProofs();

    expect(result.pendingCount, 1);
    expect(result.syncedCount, 0);
    expect(result.failedCount, 1);
    expect(proofs.single.ipfsCid, isNull);
  });
}
