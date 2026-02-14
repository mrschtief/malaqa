import 'package:cryptography/cryptography.dart';

import 'crypto/ed25519_crypto_provider.dart';
import 'interfaces/crypto_provider.dart';

class Identity {
  Identity._({
    required this.name,
    required this.publicKey,
    required SimpleKeyPair keyPair,
  }) : _keyPair = keyPair;

  final String name;
  final List<int> publicKey;
  final SimpleKeyPair _keyPair;

  static final _ed25519 = Ed25519();

  static Future<Identity> create({required String name}) async {
    final keyPair = await _ed25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return Identity._(
      name: name,
      publicKey: publicKey.bytes,
      keyPair: keyPair,
    );
  }

  String get publicKeyHex => bytesToHex(publicKey);

  Future<List<int>> signPayload({
    required List<int> payload,
    required CryptoProvider crypto,
  }) {
    return crypto.sign(
      keyPairRef: _keyPair,
      message: payload,
    );
  }
}
