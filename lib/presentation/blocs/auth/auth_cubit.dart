import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/identity.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/face_vector.dart';
import '../../../domain/interfaces/biometric_scanner.dart';
import '../../../domain/repositories/identity_repository.dart';
import '../../../domain/security/liveness_guard.dart';
import '../../../domain/services/face_matcher_service.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthSetup extends AuthState {
  const AuthSetup({this.message = 'Create local identity to start.'});

  final String message;
}

class AuthScanning extends AuthState {
  const AuthScanning({
    this.failedAttempts = 0,
    this.lastSimilarity,
    this.livenessPrompt = 'Looking for you...',
  });

  final int failedAttempts;
  final double? lastSimilarity;
  final String livenessPrompt;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.identity,
    required this.ownerVector,
    required this.similarity,
  });

  final Ed25519Identity identity;
  final FaceVector ownerVector;
  final double similarity;
}

class AuthLocked extends AuthState {
  const AuthLocked({required this.reason});

  final String reason;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required IdentityRepository identityRepository,
    required BiometricScanner<BiometricScanRequest<CameraImage>> scanner,
    required FaceMatcherService faceMatcher,
    LivenessGuard? livenessGuard,
    this.scanInterval = const Duration(milliseconds: 500),
    this.matchThreshold = 0.8,
    this.maxFailedScans = 10,
  })  : _identityRepository = identityRepository,
        _scanner = scanner,
        _faceMatcher = faceMatcher,
        _livenessGuard = livenessGuard ?? LivenessGuard(),
        super(const AuthInitial());

  final IdentityRepository _identityRepository;
  final BiometricScanner<BiometricScanRequest<CameraImage>> _scanner;
  final FaceMatcherService _faceMatcher;
  final LivenessGuard _livenessGuard;

  final Duration scanInterval;
  final double matchThreshold;
  final int maxFailedScans;

  DateTime? _lastScanAt;
  bool _isScanInProgress = false;
  int _failedScans = 0;

  Ed25519Identity? _identity;
  FaceVector? _ownerVector;

  Future<void> checkIdentity() async {
    emit(const AuthInitial());

    final identity = await _identityRepository.getIdentity();
    final ownerVector = await _identityRepository.getOwnerFaceVector();

    if (identity == null || ownerVector == null) {
      _identity = identity;
      _ownerVector = ownerVector;
      AppLogger.log('AUTH', 'No complete local auth identity found');
      emit(
        const AuthSetup(
          message: 'Create identity and capture owner face to continue.',
        ),
      );
      return;
    }

    _identity = identity;
    _ownerVector = ownerVector;
    _failedScans = 0;
    _livenessGuard.reset();
    final prompt = _livenessGuard.promptFor(_livenessGuard.currentChallenge);
    AppLogger.log('AUTH', 'Auth identity loaded, scanning for owner');
    emit(AuthScanning(livenessPrompt: prompt));
  }

  Future<void> createIdentityFromVector({
    required FaceVector ownerVector,
    String defaultName = 'local-user',
  }) async {
    var identity = await _identityRepository.getIdentity();
    if (identity == null) {
      identity = await Identity.create(name: defaultName);
      await _identityRepository.saveIdentity(identity);
      AppLogger.log('AUTH', 'New identity created for face auth');
    }

    await _identityRepository.saveOwnerFaceVector(ownerVector);
    _identity = identity;
    _ownerVector = ownerVector;
    _failedScans = 0;
    _livenessGuard.reset();
    emit(
      AuthAuthenticated(
        identity: identity,
        ownerVector: ownerVector,
        similarity: 1.0,
      ),
    );
  }

  Future<void> processFrame(
    BiometricScanRequest<CameraImage> request,
    List<FaceBounds> faces,
  ) async {
    if (state is! AuthScanning) {
      return;
    }

    final identity = _identity;
    final ownerVector = _ownerVector;
    if (identity == null || ownerVector == null) {
      emit(
        const AuthSetup(
          message: 'Create identity and capture owner face to continue.',
        ),
      );
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
      final vectors = await _scanner.scanFaces(request, faces);
      if (vectors.isEmpty) {
        _registerMiss();
        return;
      }

      var bestSimilarity = -1.0;
      var bestIndex = -1;
      for (var i = 0; i < vectors.length; i++) {
        final vector = vectors[i];
        final similarity = _faceMatcher.compare(ownerVector, vector);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestIndex = i;
        }
      }

      if (bestSimilarity >= matchThreshold) {
        if (bestIndex < 0 || bestIndex >= faces.length) {
          _registerMiss(lastSimilarity: bestSimilarity);
          return;
        }
        final liveness = _livenessGuard.evaluate(faces[bestIndex]);
        if (!liveness.passed) {
          emit(
            AuthScanning(
              failedAttempts: _failedScans,
              lastSimilarity: bestSimilarity,
              livenessPrompt: liveness.prompt,
            ),
          );
          return;
        }
        _failedScans = 0;
        _livenessGuard.reset();
        emit(
          AuthAuthenticated(
            identity: identity,
            ownerVector: ownerVector,
            similarity: bestSimilarity,
          ),
        );
        return;
      }

      _registerMiss(lastSimilarity: bestSimilarity);
    } catch (error, stackTrace) {
      AppLogger.error(
        'AUTH',
        'Frame processing failed',
        error: error,
        stackTrace: stackTrace,
      );
      _registerMiss();
    } finally {
      _isScanInProgress = false;
    }
  }

  void resumeScanning() {
    if (_identity == null || _ownerVector == null) {
      emit(
        const AuthSetup(
          message: 'Create identity and capture owner face to continue.',
        ),
      );
      return;
    }
    _failedScans = 0;
    _livenessGuard.reset();
    final prompt = _livenessGuard.promptFor(_livenessGuard.currentChallenge);
    emit(AuthScanning(livenessPrompt: prompt));
  }

  void _registerMiss({double? lastSimilarity, String? prompt}) {
    _failedScans++;
    if (_failedScans >= maxFailedScans) {
      emit(const AuthLocked(reason: 'Owner not recognized. Retry manually.'));
      return;
    }

    emit(
      AuthScanning(
        failedAttempts: _failedScans,
        lastSimilarity: lastSimilarity,
        livenessPrompt:
            prompt ?? _livenessGuard.promptFor(_livenessGuard.currentChallenge),
      ),
    );
  }
}
