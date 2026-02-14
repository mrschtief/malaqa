import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/face_vector.dart';
import '../../../domain/entities/meeting_proof.dart';
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

class ProximityCubit extends Cubit<ProximityState> {
  ProximityCubit({
    required NearbyService nearbyService,
    required ProofImporter proofImporter,
    required FaceMatcherService faceMatcher,
    this.matchThreshold = 0.8,
    this.advertisingWindow = const Duration(seconds: 30),
  })  : _nearbyService = nearbyService,
        _proofImporter = proofImporter,
        _faceMatcher = faceMatcher,
        super(const ProximityIdle()) {
    _payloadSub = _nearbyService.payloadStream.listen(_handlePayload);
  }

  final NearbyService _nearbyService;
  final ProofImporter _proofImporter;
  final FaceMatcherService _faceMatcher;

  final double matchThreshold;
  final Duration advertisingWindow;

  StreamSubscription<NearbyPayloadEvent>? _payloadSub;
  Timer? _advertisingTimer;

  bool _isAuthenticated = false;
  String _userName = 'malaqa';
  FaceVector? _ownerVector;

  Future<void> setAuthenticated({
    required String userName,
    required FaceVector ownerVector,
  }) async {
    _isAuthenticated = true;
    _userName = userName.isEmpty ? 'malaqa' : userName;
    _ownerVector = ownerVector;

    await _nearbyService.startDiscovery(userName: _userName);
    emit(const ProximityDiscovering());
  }

  Future<void> clearAuthentication() async {
    _isAuthenticated = false;
    _ownerVector = null;
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
    await _nearbyService.startAdvertising(
      userName: _userName,
      payload: payload,
    );

    final expiresAt = DateTime.now().add(advertisingWindow);
    emit(ProximityAdvertising(expiresAt: expiresAt));

    _advertisingTimer?.cancel();
    _advertisingTimer = Timer(advertisingWindow, () async {
      if (!_isAuthenticated) {
        return;
      }
      await _nearbyService.stopAll();
      await _nearbyService.startDiscovery(userName: _userName);
      emit(const ProximityDiscovering());
    });
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
