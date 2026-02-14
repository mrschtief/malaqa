import 'dart:math';

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
    this.smileThreshold = 0.8,
    this.eyeClosedThreshold = 0.1,
  }) : _random = random ?? Random();

  final Random _random;
  final double smileThreshold;
  final double eyeClosedThreshold;

  LivenessChallenge? _activeChallenge;

  void reset() {
    _activeChallenge = null;
  }

  LivenessChallenge get currentChallenge {
    return _activeChallenge ??= _pickChallenge();
  }

  LivenessEvaluation evaluate(FaceBounds face) {
    final challenge = currentChallenge;
    final passed = switch (challenge) {
      LivenessChallenge.smile =>
        (face.smilingProbability ?? 0) >= smileThreshold,
      LivenessChallenge.blink => _isBlink(face),
    };

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
      return false;
    }
    return left <= eyeClosedThreshold && right <= eyeClosedThreshold;
  }

  String promptFor(LivenessChallenge challenge) {
    return switch (challenge) {
      LivenessChallenge.smile => 'Kurz laecheln!',
      LivenessChallenge.blink => 'Kurz blinzeln!',
    };
  }
}
