import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/domain/entities/face_vector.dart';
import 'package:malaqa/domain/interfaces/biometric_scanner.dart';
import 'package:malaqa/domain/repositories/identity_repository.dart';
import 'package:malaqa/domain/services/face_matcher_service.dart';
import 'package:malaqa/presentation/blocs/auth/auth_cubit.dart';

class InMemoryIdentityRepository implements IdentityRepository {
  Ed25519Identity? identity;
  FaceVector? ownerVector;

  @override
  Future<Ed25519Identity?> getIdentity() async => identity;

  @override
  Future<FaceVector?> getOwnerFaceVector() async => ownerVector;

  @override
  Future<void> saveIdentity(Ed25519Identity identity) async {
    this.identity = identity;
  }

  @override
  Future<void> saveOwnerFaceVector(FaceVector vector) async {
    ownerVector = vector;
  }
}

class FakeBiometricScanner
    implements BiometricScanner<BiometricScanRequest<CameraImage>> {
  List<FaceVector> nextVectors = const <FaceVector>[];

  @override
  Future<FaceVector?> captureFace(
      BiometricScanRequest<CameraImage> input) async {
    if (nextVectors.isEmpty) {
      return null;
    }
    return nextVectors.first;
  }

  @override
  Future<List<FaceVector>> scanFaces(
    BiometricScanRequest<CameraImage> input,
    List<FaceBounds> allFaces,
  ) async {
    return nextVectors;
  }
}

class DummyCameraImage implements CameraImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryIdentityRepository identityRepository;
  late FakeBiometricScanner scanner;
  late AuthCubit cubit;

  setUp(() {
    identityRepository = InMemoryIdentityRepository();
    scanner = FakeBiometricScanner();
    cubit = AuthCubit(
      identityRepository: identityRepository,
      scanner: scanner,
      faceMatcher: FaceMatcherService(),
      scanInterval: Duration.zero,
      matchThreshold: 0.8,
      maxFailedScans: 3,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('emits setup when identity or owner vector is missing', () async {
    await cubit.checkIdentity();
    expect(cubit.state, isA<AuthSetup>());
  });

  test('emits scanning when identity and owner vector exist', () async {
    identityRepository.identity = await Identity.create(name: 'Alice');
    identityRepository.ownerVector = FaceVector([1.0, 0.0, 0.0]);

    await cubit.checkIdentity();

    expect(cubit.state, isA<AuthScanning>());
  });

  test('authenticates when scanned vector matches owner vector', () async {
    final identity = await Identity.create(name: 'Alice');
    identityRepository.identity = identity;
    identityRepository.ownerVector = FaceVector([1.0, 0.0, 0.0]);
    scanner.nextVectors = <FaceVector>[
      FaceVector([0.99, 0.01, 0.0])
    ];

    await cubit.checkIdentity();
    await cubit.processFrame(
      BiometricScanRequest<CameraImage>(
        image: DummyCameraImage(),
        rotationDegrees: 0,
      ),
      const <FaceBounds>[
        FaceBounds(
          left: 0,
          top: 0,
          right: 100,
          bottom: 100,
          smilingProbability: 0.95,
          leftEyeOpenProbability: 0.0,
          rightEyeOpenProbability: 0.0,
        ),
      ],
    );

    expect(cubit.state, isA<AuthAuthenticated>());
    final authState = cubit.state as AuthAuthenticated;
    expect(authState.identity.publicKeyHex, equals(identity.publicKeyHex));
    expect(authState.similarity, greaterThanOrEqualTo(0.8));
  });
}
