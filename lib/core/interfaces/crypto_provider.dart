abstract class CryptoProvider {
  List<int> randomBytes(int length);

  Future<List<int>> sha256(List<int> data);

  Future<List<int>> sign({
    required Object keyPairRef,
    required List<int> message,
  });

  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  });
}
