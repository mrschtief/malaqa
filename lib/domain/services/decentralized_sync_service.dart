import '../../core/utils/app_logger.dart';
import '../repositories/chain_repository.dart';
import '../repositories/ipfs_repository.dart';

class DecentralizedSyncResult {
  const DecentralizedSyncResult({
    required this.pendingCount,
    required this.syncedCount,
    required this.failedCount,
  });

  final int pendingCount;
  final int syncedCount;
  final int failedCount;
}

class DecentralizedSyncService {
  DecentralizedSyncService({
    required ChainRepository chainRepository,
    required IpfsRepository ipfsRepository,
  })  : _chainRepository = chainRepository,
        _ipfsRepository = ipfsRepository;

  final ChainRepository _chainRepository;
  final IpfsRepository _ipfsRepository;

  Future<DecentralizedSyncResult> syncPendingProofs() async {
    final proofs = await _chainRepository.getAllProofs();
    final pending = proofs
        .where((proof) => proof.ipfsCid == null || proof.ipfsCid!.isEmpty)
        .toList(growable: false);

    AppLogger.log('SYNC', 'Found ${pending.length} proof(s) pending IPFS sync');

    var syncedCount = 0;
    var failedCount = 0;

    for (final proof in pending) {
      try {
        final cid = await _ipfsRepository.uploadProof(proof);
        final syncedProof = proof.copyWith(ipfsCid: cid);
        await _chainRepository.saveProof(syncedProof);
        syncedCount += 1;
        AppLogger.log('SYNC', 'Proof synced to IPFS (cid=$cid)');
      } catch (error, stackTrace) {
        failedCount += 1;
        AppLogger.error(
          'SYNC',
          'Failed to sync proof to IPFS',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return DecentralizedSyncResult(
      pendingCount: pending.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  }
}
