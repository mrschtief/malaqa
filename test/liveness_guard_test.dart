import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/domain/interfaces/biometric_scanner.dart';
import 'package:malaqa/domain/security/liveness_guard.dart';

class FixedRandom implements Random {
  FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value.toDouble();

  @override
  int nextInt(int max) => value % max;
}

void main() {
  test('smile challenge succeeds only when smile threshold is reached', () {
    final guard = LivenessGuard(random: FixedRandom(0)); // smile

    final neutral1 = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.2,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.9,
      ),
    );
    final neutral2 = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.5,
        leftEyeOpenProbability: 0.8,
        rightEyeOpenProbability: 0.8,
      ),
    );
    final smile = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.9,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.9,
      ),
    );

    expect(neutral1.challenge, LivenessChallenge.smile);
    expect(neutral1.passed, isFalse);
    expect(neutral2.passed, isFalse);
    expect(smile.passed, isTrue);
  });
}
