import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/core/interfaces/crypto_provider.dart';
import 'package:malaqa/domain/entities/face_vector.dart';
import 'package:malaqa/domain/entities/meeting_proof.dart';
import 'package:malaqa/domain/interfaces/biometric_scanner.dart';
import 'package:malaqa/domain/repositories/chain_repository.dart';
import 'package:malaqa/domain/services/face_matcher_service.dart';
import 'package:malaqa/domain/services/meeting_handshake_service.dart';
import 'package:malaqa/domain/services/meeting_participant_resolver.dart';
import 'package:malaqa/presentation/blocs/meeting/meeting_cubit.dart';

class FakeCryptoProvider implements CryptoProvider {
  @override
  Future<List<int>> sha256(List<int> payload) async =>
      List<int>.filled(32, payload.length % 255);

  @override
  Future<List<int>> sign({
    required Object keyPairRef,
    required List<int> message,
  }) async =>
      List<int>.filled(64, 1);

  @override
  Future<bool> verify({
    required List<int> message,
    required List<int> signature,
    required List<int> publicKey,
  }) async =>
      true;

  @override
  List<int> randomBytes(int length) => List<int>.filled(length, 7);
}

class FakeScanner
    implements BiometricScanner<BiometricScanRequest<CameraImage>> {
  List<FaceVector> vectors = const <FaceVector>[];

  @override
  Future<FaceVector?> captureFace(
      BiometricScanRequest<CameraImage> input) async {
    if (vectors.isEmpty) {
      return null;
    }
    return vectors.first;
  }

  @override
  Future<List<FaceVector>> scanFaces(
    BiometricScanRequest<CameraImage> input,
    List<FaceBounds> allFaces,
  ) async {
    return vectors;
  }
}

class FakeChainRepository implements ChainRepository {
  final List<MeetingProof> proofs = <MeetingProof>[];

  @override
  Future<List<MeetingProof>> getAllProofs() async => List.unmodifiable(proofs);

  @override
  Future<MeetingProof?> getLatestProof() async =>
      proofs.isEmpty ? null : proofs.last;

  @override
  Future<void> saveProof(MeetingProof proof) async {
    proofs.add(proof);
  }
}

class DummyCameraImage implements CameraImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeScanner scanner;
  late MeetingCubit cubit;
  late FakeChainRepository chainRepository;
  late Identity owner;

  setUp(() async {
    scanner = FakeScanner();
    chainRepository = FakeChainRepository();
    owner = await Identity.create(name: 'Owner');
    cubit = MeetingCubit(
      scanner: scanner,
      participantResolver: MeetingParticipantResolver(
        FaceMatcherService(),
      ),
      handshakeService: MeetingHandshakeService(FakeCryptoProvider()),
      chainRepository: chainRepository,
      crypto: FakeCryptoProvider(),
      scanInterval: Duration.zero,
      ownerThreshold: 0.75,
    );
    cubit.setAuthenticated(
      identity: owner,
      ownerVector: FaceVector(const <double>[1.0, 0.0, 0.0]),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('moves to ready when owner and guest are both detected', () async {
    scanner.vectors = <FaceVector>[
      FaceVector(const <double>[1.0, 0.0, 0.0]),
      FaceVector(const <double>[0.0, 1.0, 0.0]),
    ];

    await cubit.processFrame(
      BiometricScanRequest<CameraImage>(
        image: DummyCameraImage(),
        rotationDegrees: 0,
      ),
      const <FaceBounds>[
        FaceBounds(
          left: 0,
          top: 0,
          right: 10,
          bottom: 10,
          smilingProbability: 0.0,
          leftEyeOpenProbability: 1.0,
          rightEyeOpenProbability: 1.0,
        ),
        FaceBounds(
          left: 20,
          top: 0,
          right: 30,
          bottom: 10,
          smilingProbability: 0.95,
          leftEyeOpenProbability: 0.0,
          rightEyeOpenProbability: 0.0,
        ),
      ],
    );

    expect(cubit.state, isA<MeetingReady>());
  });

  test('captureMeeting stores proof and emits success', () async {
    scanner.vectors = <FaceVector>[
      FaceVector(const <double>[1.0, 0.0, 0.0]),
      FaceVector(const <double>[0.0, 1.0, 0.0]),
    ];
    await cubit.processFrame(
      BiometricScanRequest<CameraImage>(
        image: DummyCameraImage(),
        rotationDegrees: 0,
      ),
      const <FaceBounds>[
        FaceBounds(
          left: 0,
          top: 0,
          right: 10,
          bottom: 10,
          smilingProbability: 0.0,
          leftEyeOpenProbability: 1.0,
          rightEyeOpenProbability: 1.0,
        ),
        FaceBounds(
          left: 20,
          top: 0,
          right: 30,
          bottom: 10,
          smilingProbability: 0.95,
          leftEyeOpenProbability: 0.0,
          rightEyeOpenProbability: 0.0,
        ),
      ],
    );

    await cubit.captureMeeting();

    expect(cubit.state, isA<MeetingSuccess>());
    expect(chainRepository.proofs, hasLength(1));
  });
}
