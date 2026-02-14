import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/malaqa.dart';

List<double> vectorFor(int seed) {
  return List<double>.generate(
    512,
    (i) => ((seed + 1) * (i + 1)) / 1000.0,
  );
}

void main() {
  late FaceMatcherService matcher;

  setUp(() {
    matcher = FaceMatcherService();
  });

  test('identical vectors should return cosine similarity of 1.0', () {
    final v = FaceVector(vectorFor(1));
    final score = matcher.compare(v, v);

    expect(score, closeTo(1.0, 1e-12));
    expect(matcher.isMatch(v, v), isTrue);
  });

  test('orthogonal vectors should return cosine similarity of 0.0', () {
    final v1 = FaceVector([1.0, 0.0, 0.0]);
    final v2 = FaceVector([0.0, 1.0, 0.0]);

    final score = matcher.compare(v1, v2);
    expect(score, closeTo(0.0, 1e-12));
    expect(matcher.isMatch(v1, v2, threshold: 0.1), isFalse);
  });

  test('similar vectors should return a high similarity score', () {
    final v1 = FaceVector([1.0, 2.0, 3.0, 4.0]);
    final v2 = FaceVector([1.1, 2.05, 2.95, 4.1]);

    final score = matcher.compare(v1, v2);
    expect(score, greaterThan(0.99));
    expect(matcher.isMatch(v1, v2, threshold: 0.95), isTrue);
  });

  test('zero-vector should return 0.0 (no divide-by-zero crash)', () {
    final v1 = FaceVector([0.0, 0.0, 0.0]);
    final v2 = FaceVector([1.0, 2.0, 3.0]);

    expect(matcher.compare(v1, v2), equals(0.0));
  });
}
