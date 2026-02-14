import '../entities/meeting_proof.dart';

abstract class IpfsRepository {
  Future<String> uploadProof(MeetingProof proof);
}
