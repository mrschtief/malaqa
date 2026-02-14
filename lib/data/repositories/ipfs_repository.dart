import 'dart:async';
import 'dart:convert';

import 'package:cid/cid.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';
import '../../domain/entities/meeting_proof.dart';
import '../../domain/repositories/ipfs_repository.dart';

class IpfsUploadException implements Exception {
  const IpfsUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'IpfsUploadException: $message';
    }
    return 'IpfsUploadException: $message (cause: $cause)';
  }
}

class HttpIpfsRepository implements IpfsRepository {
  HttpIpfsRepository({
    http.Client? client,
    Uri? endpoint,
    Duration timeout = const Duration(seconds: 10),
    bool simulateOnly = true,
  })  : _client = client ?? http.Client(),
        _endpoint = endpoint,
        _timeout = timeout,
        _simulateOnly = simulateOnly;

  final http.Client _client;
  final Uri? _endpoint;
  final Duration _timeout;
  final bool _simulateOnly;

  static String computeCid(String canonicalJson) {
    return CID.createCid(canonicalJson, Multibase.base32).cid;
  }

  @override
  Future<String> uploadProof(MeetingProof proof) async {
    final canonicalJson = proof.canonicalJson();
    final localCid = computeCid(canonicalJson);
    AppLogger.log(
      'IPFS',
      'Prepared canonical proof payload (cid=$localCid)',
    );

    if (_simulateOnly || _endpoint == null) {
      AppLogger.log('IPFS', 'Simulation mode enabled, skipping remote upload');
      return localCid;
    }

    final payload = jsonEncode(<String, dynamic>{
      'cid': localCid,
      'canonicalJson': canonicalJson,
      'proof': jsonDecode(canonicalJson),
    });

    try {
      final response = await _client
          .post(
            _endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IpfsUploadException(
          'IPFS upload failed with status ${response.statusCode}',
          cause: response.body,
        );
      }

      final body = response.body.trim();
      if (body.isEmpty) {
        AppLogger.log('IPFS', 'Remote upload succeeded; using local CID');
        return localCid;
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final remoteCid = decoded['cid'] ?? decoded['Hash'];
        if (remoteCid is String && remoteCid.isNotEmpty) {
          AppLogger.log('IPFS', 'Remote upload succeeded (cid=$remoteCid)');
          return remoteCid;
        }
      }

      AppLogger.log('IPFS', 'Remote upload succeeded; response had no CID');
      return localCid;
    } on TimeoutException catch (error) {
      throw IpfsUploadException(
        'IPFS upload timed out after ${_timeout.inMilliseconds}ms',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw IpfsUploadException('IPFS client error', cause: error);
    } on FormatException catch (error) {
      throw IpfsUploadException('Invalid IPFS response format', cause: error);
    }
  }
}
