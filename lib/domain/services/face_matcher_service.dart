import 'dart:math' as math;

import '../entities/face_vector.dart';

class FaceMatcherService {
  double compare(FaceVector v1, FaceVector v2) {
    final a = v1.values;
    final b = v2.values;

    if (a.length != b.length) {
      throw ArgumentError(
        'Face vectors must have the same dimension: ${a.length} != ${b.length}',
      );
    }

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      dot += ai * bi;
      normA += ai * ai;
      normB += bi * bi;
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    final score = dot / (math.sqrt(normA) * math.sqrt(normB));
    if (score.isNaN || score.isInfinite) {
      return 0.0;
    }
    return score.clamp(-1.0, 1.0);
  }

  bool isMatch(
    FaceVector v1,
    FaceVector v2, {
    double threshold = 0.8,
  }) {
    if (threshold < -1.0 || threshold > 1.0) {
      throw ArgumentError.value(
        threshold,
        'threshold',
        'Threshold must be between -1.0 and 1.0.',
      );
    }
    return compare(v1, v2) >= threshold;
  }
}
