import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/malaqa.dart';

void main() {
  test('configureDependencies registers lazy singletons', () async {
    await configureDependencies(reset: true);

    final cryptoA = getIt<CryptoProvider>();
    final cryptoB = getIt<CryptoProvider>();
    final handshakeA = getIt<MeetingHandshakeService>();
    final handshakeB = getIt<MeetingHandshakeService>();
    final chainA = getIt<ChainManager>();
    final chainB = getIt<ChainManager>();

    expect(cryptoA, same(cryptoB));
    expect(handshakeA, same(handshakeB));
    expect(chainA, same(chainB));
  });
}
