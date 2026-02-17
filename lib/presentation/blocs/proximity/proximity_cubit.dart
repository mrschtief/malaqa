import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/crypto/ed25519_crypto_provider.dart';
import '../../../core/identity.dart';
import '../../../core/interfaces/crypto_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/face_vector.dart';
import '../../../domain/entities/meeting_proof.dart';
import '../../../domain/entities/participant_signature.dart';
import '../../../domain/services/face_matcher_service.dart';
import '../../../domain/services/proof_importer.dart';
import '../../../data/datasources/nearby_service.dart';

sealed class ProximityState {
  const ProximityState();
}

class ProximityIdle extends ProximityState {
  const ProximityIdle();
}

class ProximityDiscovering extends ProximityState {
  const ProximityDiscovering();
}

class ProximityAdvertising extends ProximityState {
  const ProximityAdvertising({required this.expiresAt});

  final DateTime expiresAt;
}

class ProximityMatchFound extends ProximityState {
  const ProximityMatchFound({
    required this.endpointId,
    required this.proof,
    required this.proofJson,
    required this.similarity,
  });

  final String endpointId;
  final MeetingProof proof;
  final String proofJson;
  final double similarity;
}

class ProximityClaiming extends ProximityState {
  const ProximityClaiming();
}

class ProximityClaimed extends ProximityState {
  const ProximityClaimed({required this.result});

  final ImportResult result;
}

class ProximityError extends ProximityState {
  const ProximityError({required this.message});

  final String message;
}

class ProximityPermissionError extends ProximityState {
  const ProximityPermissionError();
}

class ProximityCubit extends Cubit<ProximityState> {
  ProximityCubit({
    required NearbyService nearbyService,
    required ProofImporter proofImporter,
    required FaceMatcherService faceMatcher,
    required CryptoProvider crypto,
    this.matchThreshold = 0.8,
    this.advertisingWindow = const Duration(seconds: 30),
    this.signatureRequestTimeout = const Duration(seconds: 10),
    Random? random,
  })  : _nearbyService = nearbyService,
        _proofImporter = proofImporter,
        _faceMatcher = faceMatcher,
        _crypto = crypto,
        _random = random ?? Random.secure(),
        super(const ProximityIdle()) {
    _payloadSub = _nearbyService.payloadStream.listen(_handlePayload);
  }

  final NearbyService _nearbyService;
  final ProofImporter _proofImporter;
  final FaceMatcherService _faceMatcher;
  final CryptoProvider _crypto;
  final Random _random;

  final double matchThreshold;
  final Duration advertisingWindow;
  final Duration signatureRequestTimeout;

  StreamSubscription<NearbyPayloadEvent>? _payloadSub;
  Timer? _advertisingTimer;

  bool _isAuthenticated = false;
  String _userName = 'malaqa';
  Ed25519Identity? _identity;
  FaceVector? _ownerVector;
  final Map<String, Completer<ParticipantSignature?>>
      _pendingSignatureRequests = <String, Completer<ParticipantSignature?>>{};

  Future<void> setAuthenticated({
    required String userName,
    required Ed25519Identity identity,
    required FaceVector ownerVector,
  }) async {
    _isAuthenticated = true;
    _userName = userName.isEmpty ? 'malaqa' : userName;
    _identity = identity;
    _ownerVector = ownerVector;

    await _startDiscoveryOrEmitError();
  }

  Future<void> clearAuthentication() async {
    _isAuthenticated = false;
    _identity = null;
    _ownerVector = null;
    for (final pending in _pendingSignatureRequests.values) {
      if (!pending.isCompleted) {
        pending.complete(null);
      }
    }
    _pendingSignatureRequests.clear();
    _advertisingTimer?.cancel();
    _advertisingTimer = null;
    await _nearbyService.stopAll();
    emit(const ProximityIdle());
  }

  Future<void> advertiseMeeting({
    required MeetingProof proof,
    required FaceVector guestVector,
  }) async {
    if (!_isAuthenticated) {
      return;
    }

    final envelope = _ProximityEnvelope(
      proof: proof,
      guestVectorValues: guestVector.values,
    );
    final payload = jsonEncode(envelope.toJson());
    try {
      await _nearbyService.startAdvertising(
        userName: _userName,
        payload: payload,
      );
    } catch (error, stackTrace) {
      _handleProximityFailure(
        operation: 'startAdvertising',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    final expiresAt = DateTime.now().add(advertisingWindow);
    emit(ProximityAdvertising(expiresAt: expiresAt));

    _advertisingTimer?.cancel();
    _advertisingTimer = Timer(advertisingWindow, () async {
      if (!_isAuthenticated) {
        return;
      }
      try {
        await _nearbyService.stopAll();
      } catch (error, stackTrace) {
        _handleProximityFailure(
          operation: 'stopAll',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
      await _startDiscoveryOrEmitError();
    });
  }

  Future<ParticipantSignature?> requestGuestSignature({
    required MeetingProof draftProof,
    required FaceVector guestVector,
    Duration? timeout,
  }) async {
    if (!_isAuthenticated || _identity == null || _ownerVector == null) {
      return null;
    }
    if (draftProof.signatures.length != 1) {
      return null;
    }

    final requestId = _nextRequestId();
    final completer = Completer<ParticipantSignature?>();
    _pendingSignatureRequests[requestId] = completer;
    _advertisingTimer?.cancel();
    _advertisingTimer = null;

    final payload = jsonEncode(
      _MeetingSignRequestEnvelope(
        requestId: requestId,
        proof: draftProof,
        guestVectorValues: guestVector.values,
      ).toJson(),
    );

    try {
      await _nearbyService.startAdvertising(
        userName: _userName,
        payload: payload,
      );
    } catch (error, stackTrace) {
      _pendingSignatureRequests.remove(requestId);
      _handleProximityFailure(
        operation: 'signatureRequest:startAdvertising',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }

    try {
      return await completer.future.timeout(
        timeout ?? signatureRequestTimeout,
        onTimeout: () {
          AppLogger.warn('PROXIMITY', 'Guest signature request timed out');
          return null;
        },
      );
    } finally {
      _pendingSignatureRequests.remove(requestId);
      if (_isAuthenticated) {
        try {
          await _nearbyService.stopAll();
        } catch (error, stackTrace) {
          _handleProximityFailure(
            operation: 'signatureRequest:stopAll',
            error: error,
            stackTrace: stackTrace,
          );
        }
        await _startDiscoveryOrEmitError();
      }
    }
  }

  Future<void> ignoreMatch() async {
    if (_isAuthenticated) {
      emit(const ProximityDiscovering());
      return;
    }
    emit(const ProximityIdle());
  }

  Future<void> claimAndSave() async {
    final current = state;
    if (current is! ProximityMatchFound) {
      return;
    }

    emit(const ProximityClaiming());
    final result = await _proofImporter.importProof(current.proofJson);
    emit(ProximityClaimed(result: result));
  }

  Future<void> dismissClaimResult() async {
    if (_isAuthenticated) {
      emit(const ProximityDiscovering());
      return;
    }
    emit(const ProximityIdle());
  }

  Future<void> _handlePayload(NearbyPayloadEvent event) async {
    final decoded = _decodePayload(event.payload);
    if (decoded != null) {
      if (_tryResolvePendingSignatureRequest(decoded)) {
        return;
      }
      final handled = await _tryHandleIncomingSignatureRequest(
        endpointId: event.endpointId,
        decoded: decoded,
      );
      if (handled) {
        return;
      }
    }

    if (!_isAuthenticated || _ownerVector == null) {
      return;
    }

    final envelope = _ProximityEnvelope.tryParse(event.payload);
    if (envelope == null) {
      AppLogger.error('PROXIMITY', 'Invalid proximity payload');
      return;
    }

    final similarity = _faceMatcher.compare(
      FaceVector(envelope.guestVectorValues),
      _ownerVector!,
    );
    if (similarity < matchThreshold) {
      AppLogger.log(
        'PROXIMITY',
        'Payload ignored due to low similarity (${similarity.toStringAsFixed(3)})',
      );
      return;
    }

    emit(
      ProximityMatchFound(
        endpointId: event.endpointId,
        proof: envelope.proof,
        proofJson: jsonEncode(envelope.proof.toJson()),
        similarity: similarity,
      ),
    );
  }

  @override
  Future<void> close() async {
    _advertisingTimer?.cancel();
    await _nearbyService.stopAll();
    await _payloadSub?.cancel();
    return super.close();
  }

  Future<void> _startDiscoveryOrEmitError() async {
    try {
      await _nearbyService.startDiscovery(userName: _userName);
      emit(const ProximityDiscovering());
    } catch (error, stackTrace) {
      _handleProximityFailure(
        operation: 'startDiscovery',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleProximityFailure({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (_isPermissionError(error)) {
      AppLogger.error(
        'PROXIMITY',
        'Nearby $operation failed due to missing permission',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const ProximityPermissionError());
      return;
    }
    AppLogger.error(
      'PROXIMITY',
      'Nearby $operation failed',
      error: error,
      stackTrace: stackTrace,
    );
    emit(const ProximityError(message: 'Nearby not available right now.'));
  }

  bool _isPermissionError(Object error) {
    if (error.runtimeType.toString() == 'PermissionException') {
      return true;
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      return code.contains('permission') ||
          message.contains('permission') ||
          message.contains('denied') ||
          message.contains('not authorized');
    }
    return error.toString().toLowerCase().contains('permission');
  }

  Map<String, dynamic>? _decodePayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool _tryResolvePendingSignatureRequest(Map<String, dynamic> decoded) {
    final response = _MeetingSignResponseEnvelope.tryParse(decoded);
    if (response != null) {
      final completer = _pendingSignatureRequests[response.requestId];
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.signature);
      }
      return true;
    }

    final reject = _MeetingSignRejectEnvelope.tryParse(decoded);
    if (reject != null) {
      final completer = _pendingSignatureRequests[reject.requestId];
      if (completer != null && !completer.isCompleted) {
        AppLogger.warn(
          'PROXIMITY',
          'Guest signature request rejected: ${reject.reason}',
        );
        completer.complete(null);
      }
      return true;
    }
    return false;
  }

  Future<bool> _tryHandleIncomingSignatureRequest({
    required String endpointId,
    required Map<String, dynamic> decoded,
  }) async {
    final request = _MeetingSignRequestEnvelope.tryParse(decoded);
    if (request == null) {
      return false;
    }
    try {
      if (!_isAuthenticated || _identity == null || _ownerVector == null) {
        await _sendSignatureReject(
          endpointId: endpointId,
          requestId: request.requestId,
          reason: 'not-authenticated',
        );
        return true;
      }

      final similarity = _faceMatcher.compare(
        FaceVector(request.guestVectorValues),
        _ownerVector!,
      );
      if (similarity < matchThreshold) {
        await _sendSignatureReject(
          endpointId: endpointId,
          requestId: request.requestId,
          reason: 'face-mismatch',
        );
        return true;
      }

      if (!_isValidSingleSignatureProof(request.proof)) {
        await _sendSignatureReject(
          endpointId: endpointId,
          requestId: request.requestId,
          reason: 'invalid-proof-shape',
        );
        return true;
      }

      final initiatorSig = request.proof.signatures.first;
      final initiatorSigValid = await _verifySignature(
        signature: initiatorSig,
        payload: request.proof.canonicalPayload().codeUnits,
      );
      if (!initiatorSigValid) {
        await _sendSignatureReject(
          endpointId: endpointId,
          requestId: request.requestId,
          reason: 'invalid-initiator-signature',
        );
        return true;
      }

      final signed = await _identity!.signPayload(
        payload: request.proof.canonicalPayload().codeUnits,
        crypto: _crypto,
      );
      final response = _MeetingSignResponseEnvelope(
        requestId: request.requestId,
        signature: ParticipantSignature(
          publicKeyHex: _identity!.publicKeyHex,
          signatureHex: bytesToHex(signed),
        ),
      );
      await _nearbyService.sendPayload(
        endpointId: endpointId,
        payload: jsonEncode(response.toJson()),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'PROXIMITY',
        'Failed to process incoming signature request',
        error: error,
        stackTrace: stackTrace,
      );
      await _sendSignatureReject(
        endpointId: endpointId,
        requestId: request.requestId,
        reason: 'internal-error',
      );
    }
    return true;
  }

  Future<void> _sendSignatureReject({
    required String endpointId,
    required String requestId,
    required String reason,
  }) async {
    try {
      final payload = jsonEncode(
        _MeetingSignRejectEnvelope(
          requestId: requestId,
          reason: reason,
        ).toJson(),
      );
      await _nearbyService.sendPayload(
        endpointId: endpointId,
        payload: payload,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'PROXIMITY',
        'Failed to send signature reject',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _isValidSingleSignatureProof(MeetingProof proof) {
    return proof.signatures.length == 1;
  }

  Future<bool> _verifySignature({
    required ParticipantSignature signature,
    required List<int> payload,
  }) async {
    try {
      return _crypto.verify(
        message: payload,
        signature: hexToBytes(signature.signatureHex),
        publicKey: hexToBytes(signature.publicKeyHex),
      );
    } catch (_) {
      return false;
    }
  }

  String _nextRequestId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rnd = _random.nextInt(1 << 32);
    return '$ts-$rnd';
  }
}

class _ProximityEnvelope {
  const _ProximityEnvelope({
    required this.proof,
    required this.guestVectorValues,
  });

  final MeetingProof proof;
  final List<double> guestVectorValues;

  Map<String, dynamic> toJson() {
    return {
      'proof': proof.toJson(),
      'guestVector': guestVectorValues,
    };
  }

  static _ProximityEnvelope? tryParse(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final proofJson = decoded['proof'];
      final guestVectorJson = decoded['guestVector'];
      if (proofJson is! Map<String, dynamic> || guestVectorJson is! List) {
        return null;
      }

      final vectorValues = guestVectorJson
          .map((value) => (value as num).toDouble())
          .toList(growable: false);
      if (vectorValues.isEmpty) {
        return null;
      }

      return _ProximityEnvelope(
        proof: MeetingProof.fromJson(proofJson),
        guestVectorValues: vectorValues,
      );
    } catch (_, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}

const String _meetingSignRequestType = 'meeting_sign_request_v1';
const String _meetingSignResponseType = 'meeting_sign_response_v1';
const String _meetingSignRejectType = 'meeting_sign_reject_v1';

class _MeetingSignRequestEnvelope {
  const _MeetingSignRequestEnvelope({
    required this.requestId,
    required this.proof,
    required this.guestVectorValues,
  });

  final String requestId;
  final MeetingProof proof;
  final List<double> guestVectorValues;

  Map<String, dynamic> toJson() {
    return {
      'type': _meetingSignRequestType,
      'requestId': requestId,
      'proof': proof.toJson(),
      'guestVector': guestVectorValues,
    };
  }

  static _MeetingSignRequestEnvelope? tryParse(Map<String, dynamic> decoded) {
    try {
      if (decoded['type'] != _meetingSignRequestType) {
        return null;
      }
      final requestId = decoded['requestId'] as String?;
      final proofJson = decoded['proof'];
      final guestVectorJson = decoded['guestVector'];
      if (requestId == null ||
          proofJson is! Map<String, dynamic> ||
          guestVectorJson is! List) {
        return null;
      }
      final vectorValues = guestVectorJson
          .map((value) => (value as num).toDouble())
          .toList(growable: false);
      if (vectorValues.isEmpty) {
        return null;
      }
      return _MeetingSignRequestEnvelope(
        requestId: requestId,
        proof: MeetingProof.fromJson(proofJson),
        guestVectorValues: vectorValues,
      );
    } catch (_) {
      return null;
    }
  }
}

class _MeetingSignResponseEnvelope {
  const _MeetingSignResponseEnvelope({
    required this.requestId,
    required this.signature,
  });

  final String requestId;
  final ParticipantSignature signature;

  Map<String, dynamic> toJson() {
    return {
      'type': _meetingSignResponseType,
      'requestId': requestId,
      'signature': signature.toJson(),
    };
  }

  static _MeetingSignResponseEnvelope? tryParse(Map<String, dynamic> decoded) {
    try {
      if (decoded['type'] != _meetingSignResponseType) {
        return null;
      }
      final requestId = decoded['requestId'] as String?;
      final signatureJson = decoded['signature'];
      if (requestId == null || signatureJson is! Map<String, dynamic>) {
        return null;
      }
      return _MeetingSignResponseEnvelope(
        requestId: requestId,
        signature: ParticipantSignature.fromJson(signatureJson),
      );
    } catch (_) {
      return null;
    }
  }
}

class _MeetingSignRejectEnvelope {
  const _MeetingSignRejectEnvelope({
    required this.requestId,
    required this.reason,
  });

  final String requestId;
  final String reason;

  Map<String, dynamic> toJson() {
    return {
      'type': _meetingSignRejectType,
      'requestId': requestId,
      'reason': reason,
    };
  }

  static _MeetingSignRejectEnvelope? tryParse(Map<String, dynamic> decoded) {
    final type = decoded['type'];
    if (type != _meetingSignRejectType) {
      return null;
    }
    final requestId = decoded['requestId'] as String?;
    final reason = decoded['reason'] as String?;
    if (requestId == null || reason == null) {
      return null;
    }
    return _MeetingSignRejectEnvelope(
      requestId: requestId,
      reason: reason,
    );
  }
}
