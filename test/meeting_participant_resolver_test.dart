import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/malaqa.dart';

void main() {
  late MeetingParticipantResolver resolver;

  setUp(() {
    resolver = MeetingParticipantResolver(FaceMatcherService());
  });

  test('resolver identifies owner and guest from two vectors', () {
    final ownerReference = FaceVector(const <double>[1.0, 0.0, 0.0]);
    final detected = <FaceVector>[
      FaceVector(const <double>[0.0, 1.0, 0.0]),
      FaceVector(const <double>[0.95, 0.05, 0.0]),
    ];

    final result = resolver.resolve(
      detectedVectors: detected,
      ownerVector: ownerReference,
      threshold: 0.75,
    );

    expect(result.isOwnerDetected, isTrue);
    expect(result.isGuestDetected, isTrue);
    expect(result.owner, same(detected[1]));
    expect(result.guest, same(detected[0]));
  });

  test('resolver returns not detected when owner is absent', () {
    final ownerReference = FaceVector(const <double>[1.0, 0.0, 0.0]);
    final detected = <FaceVector>[
      FaceVector(const <double>[0.0, 1.0, 0.0]),
      FaceVector(const <double>[0.0, 0.0, 1.0]),
    ];

    final result = resolver.resolve(
      detectedVectors: detected,
      ownerVector: ownerReference,
      threshold: 0.75,
    );

    expect(result.isOwnerDetected, isFalse);
    expect(result.isGuestDetected, isFalse);
    expect(result.owner, isNull);
    expect(result.guest, isNull);
  });
}
