import '../../core/identity.dart';
import '../entities/face_vector.dart';
import '../entities/location_point.dart';
import '../entities/meeting_proof.dart';
import '../services/meeting_handshake_service.dart';

class CreateMeetingProofInput {
  CreateMeetingProofInput({
    required this.participantA,
    required this.participantB,
    required this.vectorA,
    required this.vectorB,
    required this.location,
    required this.previousMeetingHash,
    this.timestamp,
  });

  final Identity participantA;
  final Identity participantB;
  final FaceVector vectorA;
  final FaceVector vectorB;
  final LocationPoint location;
  final String previousMeetingHash;
  final DateTime? timestamp;
}

class CreateMeetingProofUseCase {
  CreateMeetingProofUseCase(this._handshakeService);

  final MeetingHandshakeService _handshakeService;

  Future<MeetingProof> execute(CreateMeetingProofInput input) {
    return _handshakeService.createProof(
      participantA: input.participantA,
      participantB: input.participantB,
      vectorA: input.vectorA,
      vectorB: input.vectorB,
      location: input.location,
      previousMeetingHash: input.previousMeetingHash,
      timestamp: input.timestamp,
    );
  }
}
