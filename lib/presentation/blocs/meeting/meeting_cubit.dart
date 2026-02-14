import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/identity.dart';
import '../../../core/interfaces/crypto_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/face_vector.dart';
import '../../../domain/entities/location_point.dart';
import '../../../domain/entities/meeting_proof.dart';
import '../../../domain/interfaces/biometric_scanner.dart';
import '../../../domain/repositories/chain_repository.dart';
import '../../../domain/security/liveness_guard.dart';
import '../../../domain/services/meeting_handshake_service.dart';
import '../../../domain/services/meeting_participant_resolver.dart';

sealed class MeetingState {
  const MeetingState();
}

class MeetingIdle extends MeetingState {
  const MeetingIdle({this.message = 'Only owner in frame.'});

  final String message;
}

class MeetingReady extends MeetingState {
  const MeetingReady({
    required this.guest,
    required this.guestBounds,
    required this.isLivenessVerified,
    required this.livenessPrompt,
  });

  final FaceVector guest;
  final FaceBounds guestBounds;
  final bool isLivenessVerified;
  final String livenessPrompt;
}

class MeetingCapturing extends MeetingState {
  const MeetingCapturing();
}

class MeetingSuccess extends MeetingState {
  const MeetingSuccess({
    required this.proof,
    required this.chainIndex,
    required this.guestVector,
  });

  final MeetingProof proof;
  final int chainIndex;
  final FaceVector guestVector;
}

class MeetingError extends MeetingState {
  const MeetingError({required this.message});

  final String message;
}

class MeetingCubit extends Cubit<MeetingState> {
  MeetingCubit({
    required BiometricScanner<BiometricScanRequest<CameraImage>> scanner,
    required MeetingParticipantResolver participantResolver,
    required MeetingHandshakeService handshakeService,
    required ChainRepository chainRepository,
    required CryptoProvider crypto,
    LivenessGuard? livenessGuard,
    this.scanInterval = const Duration(milliseconds: 500),
    this.ownerThreshold = 0.75,
  })  : _scanner = scanner,
        _participantResolver = participantResolver,
        _handshakeService = handshakeService,
        _chainRepository = chainRepository,
        _crypto = crypto,
        _livenessGuard = livenessGuard ?? LivenessGuard(),
        super(const MeetingIdle());

  final BiometricScanner<BiometricScanRequest<CameraImage>> _scanner;
  final MeetingParticipantResolver _participantResolver;
  final MeetingHandshakeService _handshakeService;
  final ChainRepository _chainRepository;
  final CryptoProvider _crypto;
  final LivenessGuard _livenessGuard;

  final Duration scanInterval;
  final double ownerThreshold;

  DateTime? _lastScanAt;
  bool _isScanInProgress = false;

  Ed25519Identity? _ownerIdentity;
  FaceVector? _ownerVector;

  FaceVector? _guestVector;
  FaceBounds? _guestBounds;
  bool _guestLivenessVerified = false;
  BiometricScanRequest<CameraImage>? _lastRequest;
  List<FaceBounds>? _lastFaces;

  void setAuthenticated({
    required Ed25519Identity identity,
    required FaceVector ownerVector,
  }) {
    _ownerIdentity = identity;
    _ownerVector = ownerVector;
    _guestVector = null;
    _guestBounds = null;
    _guestLivenessVerified = false;
    _livenessGuard.reset();
    _lastRequest = null;
    _lastFaces = null;
    emit(const MeetingIdle(message: 'Bring a guest into frame.'));
  }

  void clearAuthentication() {
    _ownerIdentity = null;
    _ownerVector = null;
    _guestVector = null;
    _guestBounds = null;
    _guestLivenessVerified = false;
    _livenessGuard.reset();
    _lastRequest = null;
    _lastFaces = null;
    emit(const MeetingIdle(message: 'Waiting for owner authentication.'));
  }

  Future<void> processFrame(
    BiometricScanRequest<CameraImage> request,
    List<FaceBounds> faces,
  ) async {
    if (_ownerIdentity == null || _ownerVector == null) {
      return;
    }
    if (state is MeetingCapturing) {
      return;
    }

    if (faces.length < 2) {
      _guestVector = null;
      _guestBounds = null;
      _guestLivenessVerified = false;
      _livenessGuard.reset();
      _lastRequest = null;
      _lastFaces = null;
      if (state is! MeetingIdle) {
        emit(const MeetingIdle(message: 'Only owner in frame.'));
      }
      return;
    }
    if (faces.length > 2) {
      _guestVector = null;
      _guestBounds = null;
      _guestLivenessVerified = false;
      _livenessGuard.reset();
      _lastRequest = null;
      _lastFaces = null;
      emit(const MeetingError(message: 'Too many faces. Keep exactly two.'));
      return;
    }

    final now = DateTime.now();
    if (_lastScanAt != null && now.difference(_lastScanAt!) < scanInterval) {
      return;
    }
    if (_isScanInProgress) {
      return;
    }
    _lastScanAt = now;
    _isScanInProgress = true;

    try {
      _lastRequest = request;
      _lastFaces = List<FaceBounds>.unmodifiable(faces);
      final vectors = await _scanner.scanFaces(request, faces);
      if (vectors.length < 2) {
        emit(const MeetingError(message: 'Could not read both faces.'));
        return;
      }

      final resolved = _participantResolver.resolve(
        detectedVectors: vectors,
        ownerVector: _ownerVector!,
        threshold: ownerThreshold,
      );

      if (!resolved.isOwnerDetected) {
        _guestVector = null;
        _guestBounds = null;
        emit(const MeetingError(message: 'Owner lost. Look at camera.'));
        return;
      }

      if (!resolved.isGuestDetected ||
          resolved.guest == null ||
          resolved.guestIndex == null ||
          resolved.guestIndex! >= faces.length) {
        _guestVector = null;
        _guestBounds = null;
        emit(const MeetingIdle(message: 'Waiting for guest.'));
        return;
      }

      _guestVector = resolved.guest;
      _guestBounds = faces[resolved.guestIndex!];
      final liveness = _livenessGuard.evaluate(_guestBounds!);
      _guestLivenessVerified = liveness.passed;
      emit(
        MeetingReady(
          guest: _guestVector!,
          guestBounds: _guestBounds!,
          isLivenessVerified: _guestLivenessVerified,
          livenessPrompt: liveness.prompt,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'MEETING',
        'Failed to process meeting frame',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const MeetingError(message: 'Meeting scan failed.'));
    } finally {
      _isScanInProgress = false;
    }
  }

  Future<void> captureMeeting() async {
    final ownerIdentity = _ownerIdentity;
    final ownerVector = _ownerVector;
    final initialGuestVector = _guestVector;
    if (ownerIdentity == null ||
        ownerVector == null ||
        initialGuestVector == null ||
        !_guestLivenessVerified) {
      emit(const MeetingError(message: 'Meeting not ready yet.'));
      return;
    }
    var guestVector = initialGuestVector;

    emit(const MeetingCapturing());

    try {
      final latestRequest = _lastRequest;
      final latestFaces = _lastFaces;
      if (latestRequest != null && latestFaces != null) {
        final latestVectors =
            await _scanner.scanFaces(latestRequest, latestFaces);
        if (latestVectors.length >= 2) {
          final latestResolved = _participantResolver.resolve(
            detectedVectors: latestVectors,
            ownerVector: ownerVector,
            threshold: ownerThreshold,
          );
          if (latestResolved.isGuestDetected && latestResolved.guest != null) {
            guestVector = latestResolved.guest!;
          }
        }
      }

      final latest = await _chainRepository.getLatestProof();
      var previousHash = '0000';
      if (latest != null) {
        previousHash = await latest.computeProofHash(_crypto);
      }

      // MVP single-device limitation:
      // guest key is generated locally as placeholder until real P2P handshake.
      final guestPlaceholder = await Identity.create(name: 'guest-mvp');

      final proof = await _handshakeService.createProof(
        participantA: ownerIdentity,
        participantB: guestPlaceholder,
        vectorA: ownerVector,
        vectorB: guestVector,
        location: const LocationPoint(latitude: 0.0, longitude: 0.0),
        previousMeetingHash: previousHash,
        timestamp: DateTime.now().toUtc(),
      );

      await _chainRepository.saveProof(proof);
      final allProofs = await _chainRepository.getAllProofs();
      emit(
        MeetingSuccess(
          proof: proof,
          chainIndex: allProofs.length,
          guestVector: guestVector,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'MEETING',
        'Failed to capture meeting proof',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const MeetingError(message: 'Could not save meeting proof.'));
    }
  }

  void resetAfterSuccess() {
    if (_ownerIdentity == null || _ownerVector == null) {
      emit(const MeetingIdle(message: 'Waiting for owner authentication.'));
      return;
    }
    _guestVector = null;
    _guestBounds = null;
    _guestLivenessVerified = false;
    _livenessGuard.reset();
    _lastRequest = null;
    _lastFaces = null;
    emit(const MeetingIdle(message: 'Bring a guest into frame.'));
  }
}
