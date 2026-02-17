import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/utils/app_logger.dart';
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
  test('liveness passes when smile probability is above threshold', () {
    AppLogger.clear();
    final guard = LivenessGuard(random: FixedRandom(0)); // smile

    final neutral = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.6,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.9,
      ),
    );
    final smile = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.61,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.9,
      ),
    );

    expect(neutral.challenge, LivenessChallenge.smile);
    expect(neutral.passed, isFalse);
    expect(smile.passed, isTrue);
    expect(
      AppLogger.logs.any((line) => line.contains('Current Smile Prob')),
      isTrue,
    );
  });

  test('liveness passes when left eye is closed enough (blink)', () {
    AppLogger.clear();
    final guard = LivenessGuard(random: FixedRandom(1)); // blink

    final openEyes = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.0,
        leftEyeOpenProbability: 0.7,
        rightEyeOpenProbability: 0.8,
      ),
    );
    final notClosedEnough = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.0,
        leftEyeOpenProbability: 0.2,
        rightEyeOpenProbability: 0.2,
      ),
    );
    final blink = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.0,
        leftEyeOpenProbability: 0.19,
        rightEyeOpenProbability: 0.95,
      ),
    );

    expect(openEyes.challenge, LivenessChallenge.blink);
    expect(openEyes.passed, isFalse);
    expect(notClosedEnough.passed, isFalse);
    expect(blink.passed, isTrue);
    expect(
      AppLogger.logs.any((line) => line.contains('Current Eye Open Prob')),
      isTrue,
    );
  });

  test('liveness passes on smile even when challenge is blink', () {
    final guard = LivenessGuard(random: FixedRandom(1)); // blink

    final result = guard.evaluate(
      const FaceBounds(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        smilingProbability: 0.95,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.9,
      ),
    );

    expect(result.challenge, LivenessChallenge.blink);
    expect(result.passed, isTrue);
    expect(result.prompt, 'Bitte laecheln ODER kurz blinzeln');
  });
}
