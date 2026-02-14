import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/repositories/anchor_repository.dart';
import '../../domain/services/crypto_wallet_service.dart';

typedef RawTransactionSender = Future<String> Function(Uint8List signedTx);

class PreparedAnchorTransaction {
  const PreparedAnchorTransaction({
    required this.transaction,
    required this.callData,
    required this.unsignedPayload,
    required this.signature,
    required this.signerAddress,
    required this.signerPublicKey,
    required this.signedTransaction,
    required this.localTransactionHash,
  });

  final Transaction transaction;
  final Uint8List callData;
  final Uint8List unsignedPayload;
  final web3_crypto.MsgSignature signature;
  final EthereumAddress signerAddress;
  final Uint8List signerPublicKey;
  final Uint8List signedTransaction;
  final String localTransactionHash;
}

class EthereumAnchorRepository implements AnchorRepository {
  EthereumAnchorRepository({
    required String rpcUrl,
    required CryptoWalletService walletService,
    int chainId = 80002,
    EthereumAddress? contractAddress,
    http.Client? httpClient,
    RawTransactionSender? sendRawTransaction,
    bool simulateOnly = true,
    int startingNonce = 0,
  })  : _walletService = walletService,
        _chainId = chainId,
        _contractAddress = contractAddress ?? defaultContractAddress,
        _sendRawTransaction = sendRawTransaction,
        _simulateOnly = simulateOnly,
        _nextNonce = startingNonce,
        _client = Web3Client(rpcUrl, httpClient ?? http.Client());

  static final EthereumAddress defaultContractAddress = EthereumAddress.fromHex(
    '0x000000000000000000000000000000000000dEaD',
  );

  final CryptoWalletService _walletService;
  final int _chainId;
  final EthereumAddress _contractAddress;
  final RawTransactionSender? _sendRawTransaction;
  final bool _simulateOnly;
  final Web3Client _client;
  int _nextNonce;

  static Uint8List encodeStoreHashCallData(String proofHash) {
    final normalizedHash = _normalizeProofHash(proofHash);
    final selector = web3_crypto.keccakUtf8('storeHash(bytes32)').sublist(0, 4);
    final hashBytes = web3_crypto.hexToBytes(normalizedHash);
    return Uint8List.fromList(<int>[...selector, ...hashBytes]);
  }

  static String _normalizeProofHash(String proofHash) {
    final normalized = web3_crypto.strip0x(proofHash).toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      throw FormatException('proofHash must be a 32-byte hex string.');
    }
    return normalized;
  }

  Future<PreparedAnchorTransaction> prepareAnchorTransaction(
    String proofHash,
  ) async {
    final credentials = await _walletService.getEthereumCredentials();
    final callData = encodeStoreHashCallData(proofHash);
    final nonce = _nextNonce++;

    final transaction = Transaction(
      to: _contractAddress,
      value: EtherAmount.zero(),
      data: callData,
      nonce: nonce,
      maxGas: 120000,
      gasPrice: EtherAmount.inWei(BigInt.one),
    );

    final unsignedPayload =
        transaction.getUnsignedSerialized(chainId: _chainId);
    final signature = credentials.signToEcSignature(
      unsignedPayload,
      chainId: _chainId,
    );
    final signedTransaction = await _client.signTransaction(
      credentials,
      transaction,
      chainId: _chainId,
    );
    final localTransactionHash = web3_crypto.bytesToHex(
      web3_crypto.keccak256(signedTransaction),
      include0x: true,
    );

    return PreparedAnchorTransaction(
      transaction: transaction,
      callData: callData,
      unsignedPayload: unsignedPayload,
      signature: signature,
      signerAddress: credentials.address,
      signerPublicKey: credentials.encodedPublicKey,
      signedTransaction: signedTransaction,
      localTransactionHash: localTransactionHash,
    );
  }

  @override
  Future<String> anchorProof(String proofHash) async {
    final prepared = await prepareAnchorTransaction(proofHash);

    if (_simulateOnly) {
      AppLogger.log(
        'ANCHOR',
        'Simulated anchor tx created (txHash=${prepared.localTransactionHash})',
      );
      return prepared.localTransactionHash;
    }

    final sender = _sendRawTransaction ?? _client.sendRawTransaction;
    final txHash = await sender(prepared.signedTransaction);
    AppLogger.log(
      'ANCHOR',
      'Proof hash anchored on chain (txHash=$txHash)',
    );
    return txHash;
  }
}
