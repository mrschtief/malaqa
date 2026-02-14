import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import '../../core/interfaces/crypto_provider.dart';
import '../../core/utils/app_logger.dart';
import '../repositories/identity_repository.dart';

class CryptoWalletService {
  CryptoWalletService({
    required IdentityRepository identityRepository,
    required CryptoProvider crypto,
  })  : _identityRepository = identityRepository,
        _crypto = crypto;

  final IdentityRepository _identityRepository;
  final CryptoProvider _crypto;

  static final BigInt _secp256k1Order = web3_crypto.hexToInt(
    '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
  );

  Future<String> deriveMnemonic({String passphrase = ''}) async {
    final entropy = await _deriveIdentityEntropy();
    final mnemonic = bip39.entropyToMnemonic(web3_crypto.bytesToHex(entropy));
    if (!bip39.validateMnemonic(mnemonic)) {
      throw StateError('Generated mnemonic is invalid.');
    }
    return mnemonic;
  }

  Future<String> getEthereumPrivateKeyHex({String passphrase = ''}) async {
    final mnemonic = await deriveMnemonic(passphrase: passphrase);
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);

    if (seed.length < 32) {
      throw StateError('BIP39 seed is too short to derive Ethereum key.');
    }

    final privateKeyBytes = await _normalizeToValidPrivateKey(
      Uint8List.fromList(seed.sublist(0, 32)),
    );

    final privateKeyHex = web3_crypto.bytesToHex(
      privateKeyBytes,
      include0x: true,
      forcePadLength: 64,
    );
    AppLogger.log(
      'ANCHOR',
      'Derived deterministic Ethereum key from local identity seed',
    );
    return privateKeyHex;
  }

  Future<EthPrivateKey> getEthereumCredentials({String passphrase = ''}) async {
    final privateKeyHex = await getEthereumPrivateKeyHex(
      passphrase: passphrase,
    );
    return EthPrivateKey.fromHex(privateKeyHex);
  }

  Future<Uint8List> _deriveIdentityEntropy() async {
    final identity = await _identityRepository.getIdentity();
    if (identity == null) {
      throw StateError('No local identity available for wallet derivation.');
    }

    final privateKeyBytes = await identity.exportPrivateKeyBytes();
    final entropy = await _crypto.sha256(privateKeyBytes);
    return Uint8List.fromList(entropy.sublist(0, 16));
  }

  Future<Uint8List> _normalizeToValidPrivateKey(Uint8List initialBytes) async {
    var candidate = initialBytes;

    for (var i = 0; i < 64; i++) {
      final candidateInt = web3_crypto.bytesToUnsignedInt(candidate);
      if (candidateInt > BigInt.zero && candidateInt < _secp256k1Order) {
        return candidate;
      }

      final rehashInput = Uint8List(candidate.length + 1)
        ..setAll(0, candidate)
        ..[candidate.length] = i;
      candidate = Uint8List.fromList(await _crypto.sha256(rehashInput));
    }

    throw StateError('Unable to derive a valid secp256k1 private key.');
  }
}
