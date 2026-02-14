import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../interfaces/crypto_provider.dart';

class Ed25519CryptoProvider implements CryptoProvider {
  Ed25519CryptoProvider({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;
  final _ed25519 = Ed25519();
  final _sha256 = Sha256();

  @override
  List<int> randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  @override
  Future<List<int>> sha256(List<int> data) async {
    final digest = await _sha256.hash(data);
    return digest.bytes;
  }

  @override
  Future<List<int>> sign({
    required Object keyPairRef,
    required List<int> message,
  }) async {
    final keyPair = keyPairRef as SimpleKeyPair;
    final signature = await _ed25519.sign(message, keyPair: keyPair);
    return signature.bytes;
  }

  @override
  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  }) async {
    final sig = Signature(
      signature,
      publicKey: SimplePublicKey(
        publicKey,
        type: KeyPairType.ed25519,
      ),
    );
    return _ed25519.verify(message, signature: sig);
  }
}

Uint8List doublesToBytes(List<double> values) {
  final out = BytesBuilder(copy: false);
  for (final value in values) {
    final data = ByteData(8)..setFloat64(0, value, Endian.little);
    out.add(data.buffer.asUint8List());
  }
  return out.toBytes();
}

String bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

List<int> hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw FormatException('Hex string must have even length.');
  }
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
