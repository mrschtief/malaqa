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
    this.smileThreshold = 0.6,
    this.blinkThreshold = 0.2,
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

    AppLogger.log(
      'LIVENESS',
      'Current Smile Prob: $smileProb (threshold=$smileThreshold)',
    );
    AppLogger.log(
      'LIVENESS',
      'Current Eye Open Prob: left=$leftEyeOpenProb '
          '(blinkThreshold=$blinkThreshold)',
    );
    final passed = smileProb > smileThreshold || _isBlink(face);
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
    if (left == null) {
      AppLogger.log(
        'LIVENESS',
        'Blink evaluation skipped: missing left eye probability',
      );
      return false;
    }
    return left < blinkThreshold;
  }

  String promptFor(LivenessChallenge challenge) {
    return 'Bitte laecheln ODER kurz blinzeln';
  }
}
