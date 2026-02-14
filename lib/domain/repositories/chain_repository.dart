import '../entities/meeting_proof.dart';

abstract class ChainRepository {
  Future<void> saveProof(MeetingProof proof);

  Future<List<MeetingProof>> getAllProofs();

  Future<MeetingProof?> getLatestProof();
}
