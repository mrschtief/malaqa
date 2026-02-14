import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/malaqa.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

class _FakeIdentityRepository implements IdentityRepository {
  _FakeIdentityRepository(this._identity);

  Ed25519Identity? _identity;
  FaceVector? _ownerVector;

  @override
  Future<Ed25519Identity?> getIdentity() async => _identity;

  @override
  Future<void> saveIdentity(Ed25519Identity identity) async {
    _identity = identity;
  }

  @override
  Future<FaceVector?> getOwnerFaceVector() async => _ownerVector;

  @override
  Future<void> saveOwnerFaceVector(FaceVector vector) async {
    _ownerVector = vector;
  }
}

void main() {
  test('CryptoWalletService derives deterministic Ethereum key + mnemonic',
      () async {
    final identity = await Identity.create(name: 'Alice');
    final walletService = CryptoWalletService(
      identityRepository: _FakeIdentityRepository(identity),
      crypto: Ed25519CryptoProvider(),
    );

    final keyHexA = await walletService.getEthereumPrivateKeyHex();
    final keyHexB = await walletService.getEthereumPrivateKeyHex();
    final mnemonic = await walletService.deriveMnemonic();
    final credentials = await walletService.getEthereumCredentials();

    expect(keyHexA, keyHexB);
    expect(keyHexA, startsWith('0x'));
    expect(web3_crypto.strip0x(keyHexA).length, 64);
    expect(bip39.validateMnemonic(mnemonic), isTrue);
    expect(credentials.privateKey.length, 32);
  });

  test(
      'EthereumAnchorRepository prepares valid signed transaction with encoded proof hash',
      () async {
    final identity = await Identity.create(name: 'Bob');
    final walletService = CryptoWalletService(
      identityRepository: _FakeIdentityRepository(identity),
      crypto: Ed25519CryptoProvider(),
    );

    final repository = EthereumAnchorRepository(
      rpcUrl: 'http://127.0.0.1:8545',
      walletService: walletService,
      chainId: 80002,
      contractAddress:
          EthereumAddress.fromHex('0x000000000000000000000000000000000000dEaD'),
      simulateOnly: true,
      startingNonce: 7,
    );

    final proofHash = 'ab' * 32;
    final prepared = await repository.prepareAnchorTransaction(proofHash);

    final expectedCallData =
        EthereumAnchorRepository.encodeStoreHashCallData(proofHash);

    expect(prepared.callData, orderedEquals(expectedCallData));
    expect(prepared.callData.length, 36);
    expect(prepared.transaction.nonce, 7);

    final messageHash = web3_crypto.keccak256(prepared.unsignedPayload);
    final normalizedSignature = web3_crypto.MsgSignature(
      prepared.signature.r,
      prepared.signature.s,
      prepared.signature.v - (80002 * 2 + 35) + 27,
    );
    final signatureValid = web3_crypto.isValidSignature(
      messageHash,
      normalizedSignature,
      prepared.signerPublicKey,
    );
    expect(signatureValid, isTrue);

    final derivedSigner = EthereumAddress(
      web3_crypto.publicKeyToAddress(prepared.signerPublicKey),
    );
    expect(derivedSigner.hexEip55, prepared.signerAddress.hexEip55);

    final signedHex = web3_crypto.bytesToHex(prepared.signedTransaction);
    expect(
      signedHex.contains(web3_crypto.bytesToHex(expectedCallData)),
      isTrue,
    );
  });

  test('anchorProof uses mocked sender when simulateOnly is false', () async {
    final identity = await Identity.create(name: 'Charlie');
    final walletService = CryptoWalletService(
      identityRepository: _FakeIdentityRepository(identity),
      crypto: Ed25519CryptoProvider(),
    );

    Uint8List? capturedRaw;
    final repository = EthereumAnchorRepository(
      rpcUrl: 'http://127.0.0.1:8545',
      walletService: walletService,
      chainId: 80002,
      simulateOnly: false,
      sendRawTransaction: (signedTx) async {
        capturedRaw = signedTx;
        return '0xmockedtxhash';
      },
    );

    final txHash = await repository.anchorProof('cd' * 32);

    expect(txHash, '0xmockedtxhash');
    expect(capturedRaw, isNotNull);
    expect(capturedRaw, isNotEmpty);
  });

  test('anchorProof returns local tx hash in simulation mode', () async {
    final identity = await Identity.create(name: 'Diana');
    final walletService = CryptoWalletService(
      identityRepository: _FakeIdentityRepository(identity),
      crypto: Ed25519CryptoProvider(),
    );

    var senderCalls = 0;
    final repository = EthereumAnchorRepository(
      rpcUrl: 'http://127.0.0.1:8545',
      walletService: walletService,
      simulateOnly: true,
      sendRawTransaction: (_) async {
        senderCalls += 1;
        return '0xshouldnotbecalled';
      },
    );

    final txHash = await repository.anchorProof('ef' * 32);

    expect(txHash, startsWith('0x'));
    expect(web3_crypto.strip0x(txHash).length, 64);
    expect(senderCalls, 0);
  });
}
