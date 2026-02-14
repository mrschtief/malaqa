import '../entities/face_vector.dart';
import 'face_matcher_service.dart';

class ScanResult {
  const ScanResult({
    required this.owner,
    required this.guest,
    required this.ownerIndex,
    required this.guestIndex,
    required this.isOwnerDetected,
    required this.isGuestDetected,
  });

  final FaceVector? owner;
  final FaceVector? guest;
  final int? ownerIndex;
  final int? guestIndex;
  final bool isOwnerDetected;
  final bool isGuestDetected;
}

class MeetingParticipantResolver {
  MeetingParticipantResolver(this._faceMatcher);

  final FaceMatcherService _faceMatcher;

  ScanResult resolve({
    required List<FaceVector> detectedVectors,
    required FaceVector ownerVector,
    double threshold = 0.75,
  }) {
    if (detectedVectors.isEmpty) {
      return const ScanResult(
        owner: null,
        guest: null,
        ownerIndex: null,
        guestIndex: null,
        isOwnerDetected: false,
        isGuestDetected: false,
      );
    }

    var ownerIndex = -1;
    var bestScore = threshold;

    for (var i = 0; i < detectedVectors.length; i++) {
      final score = _faceMatcher.compare(detectedVectors[i], ownerVector);
      if (score >= bestScore) {
        bestScore = score;
        ownerIndex = i;
      }
    }

    if (ownerIndex < 0) {
      return const ScanResult(
        owner: null,
        guest: null,
        ownerIndex: null,
        guestIndex: null,
        isOwnerDetected: false,
        isGuestDetected: false,
      );
    }

    final owner = detectedVectors[ownerIndex];
    FaceVector? guest;
    int? guestIndex;
    for (var i = 0; i < detectedVectors.length; i++) {
      if (i == ownerIndex) {
        continue;
      }
      guest = detectedVectors[i];
      guestIndex = i;
      break;
    }

    return ScanResult(
      owner: owner,
      guest: guest,
      ownerIndex: ownerIndex,
      guestIndex: guestIndex,
      isOwnerDetected: true,
      isGuestDetected: guest != null,
    );
  }
}
