import '../../core/crypto/ed25519_crypto_provider.dart';

class FaceVector {
  FaceVector(List<double> values) : values = List<double>.unmodifiable(values) {
    if (values.isEmpty) {
      throw ArgumentError.value(
          values, 'values', 'FaceVector cannot be empty.');
    }
  }

  final List<double> values;

  Future<String> saltedHash({
    required List<int> salt,
    required Future<List<int>> Function(List<int>) hasher,
  }) async {
    final vectorBytes = doublesToBytes(values);
    final payload = <int>[...salt, ...vectorBytes];
    final digest = await hasher(payload);
    return bytesToHex(digest);
  }
}
