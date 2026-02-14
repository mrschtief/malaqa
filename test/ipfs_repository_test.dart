import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:malaqa/malaqa.dart';

List<double> _vectorFor(int seed) {
  return List<double>.generate(
    512,
    (i) => ((seed + 1) * (i + 1)) / 1000.0,
  );
}

class _TestClient extends http.BaseClient {
  _TestClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

http.StreamedResponse _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream<List<int>>.fromIterable([bytes]),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}

Future<MeetingProof> _createProof() async {
  final crypto = Ed25519CryptoProvider();
  final handshake = MeetingHandshakeService(crypto);
  final alice = await Identity.create(name: 'Alice');
  final bob = await Identity.create(name: 'Bob');

  return handshake.createProof(
    participantA: alice,
    participantB: bob,
    vectorA: FaceVector(_vectorFor(1)),
    vectorB: FaceVector(_vectorFor(2)),
    location: const LocationPoint(latitude: 52.52, longitude: 13.405),
    previousMeetingHash: '0000',
    timestamp: DateTime.utc(2026, 2, 14, 23, 0, 0),
  );
}

void main() {
  test('simulated upload returns deterministic CID from canonical proof JSON',
      () async {
    final proof = await _createProof();
    final repository = HttpIpfsRepository(simulateOnly: true);

    final cid = await repository.uploadProof(proof);
    final expected = HttpIpfsRepository.computeCid(proof.canonicalJson());

    expect(cid, expected);
    expect(cid, startsWith('b'));
  });

  test('http upload sends canonical JSON payload and prefers remote CID',
      () async {
    final proof = await _createProof();
    late Map<String, dynamic> requestBody;

    final client = _TestClient((request) async {
      expect(request.url.toString(), 'https://ipfs.example/upload');
      expect(request.method, 'POST');

      final data = await request.finalize().toBytes();
      requestBody = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;

      return _jsonResponse({'cid': 'bafyremoteproofcid123'});
    });

    final repository = HttpIpfsRepository(
      client: client,
      endpoint: Uri.parse('https://ipfs.example/upload'),
      simulateOnly: false,
    );

    final cid = await repository.uploadProof(proof);

    expect(cid, 'bafyremoteproofcid123');
    expect(requestBody['canonicalJson'], proof.canonicalJson());
    expect(requestBody['proof'], jsonDecode(proof.canonicalJson()));
    expect(
      requestBody['cid'],
      HttpIpfsRepository.computeCid(proof.canonicalJson()),
    );
  });

  test('http upload throws IpfsUploadException on timeout', () async {
    final proof = await _createProof();

    final client = _TestClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return _jsonResponse({'cid': 'never-returned'});
    });

    final repository = HttpIpfsRepository(
      client: client,
      endpoint: Uri.parse('https://ipfs.example/upload'),
      simulateOnly: false,
      timeout: const Duration(milliseconds: 5),
    );

    expect(
      () => repository.uploadProof(proof),
      throwsA(isA<IpfsUploadException>()),
    );
  });
}
