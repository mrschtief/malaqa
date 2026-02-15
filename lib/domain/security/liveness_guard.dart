import 'dart:math';

import '../../core/utils/app_logger.dart';
import '../interfaces/biometric_scanner.dart';

enum LivenessChallenge {
  smile,
  blink,
}

class LivenessEvaluation {
  const LivenessEvaluation({
    required this.challenge,
    required this.passed,
    required this.prompt,
  });

  final LivenessChallenge challenge;
  final bool passed;
  final String prompt;
}

class LivenessGuard {
  LivenessGuard({
    Random? random,
    this.smileThreshold = 0.4,
    this.blinkThreshold = 0.3,
  }) : _random = random ?? Random();

  final Random _random;
  final double smileThreshold;
  final double blinkThreshold;

  LivenessChallenge? _activeChallenge;

  void reset() {
    _activeChallenge = null;
  }

  LivenessChallenge get currentChallenge {
    return _activeChallenge ??= _pickChallenge();
  }

  LivenessEvaluation evaluate(FaceBounds face) {
    final challenge = currentChallenge;
    final smileProb = face.smilingProbability ?? 0;
    final leftEyeOpenProb = face.leftEyeOpenProbability;
    final rightEyeOpenProb = face.rightEyeOpenProbability;

    AppLogger.log(
      'LIVENESS',
      'Current Smile Prob: $smileProb (threshold=$smileThreshold)',
    );
    AppLogger.log(
      'LIVENESS',
      'Current Eye Open Probs: left=$leftEyeOpenProb right=$rightEyeOpenProb '
          '(blinkThreshold=$blinkThreshold)',
    );
    final passed = switch (challenge) {
      LivenessChallenge.smile => smileProb >= smileThreshold,
      LivenessChallenge.blink => _isBlink(face),
    };
    AppLogger.log(
      'LIVENESS',
      'Challenge=$challenge result=${passed ? 'PASSED' : 'FAILED'}',
    );

    return LivenessEvaluation(
      challenge: challenge,
      passed: passed,
      prompt: promptFor(challenge),
    );
  }

  LivenessChallenge _pickChallenge() {
    final next = _random.nextInt(2);
    return next == 0 ? LivenessChallenge.smile : LivenessChallenge.blink;
  }

  bool _isBlink(FaceBounds face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) {
      AppLogger.log(
        'LIVENESS',
        'Blink evaluation skipped: missing eye probabilities',
      );
      return false;
    }
    return left <= blinkThreshold && right <= blinkThreshold;
  }

  String promptFor(LivenessChallenge challenge) {
    return switch (challenge) {
      LivenessChallenge.smile => 'Kurz laecheln!',
      LivenessChallenge.blink => 'Kurz blinzeln!',
    };
  }
}
