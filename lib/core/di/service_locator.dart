import 'package:camera/camera.dart';
import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/secure_key_value_store.dart';
import '../../data/datasources/tflite_biometric_scanner.dart';
import '../../data/models/meeting_proof_model.dart';
import '../../data/repositories/isar_chain_repository.dart';
import '../../data/repositories/secure_identity_repository.dart';
import '../../domain/interfaces/biometric_scanner.dart';
import '../../domain/repositories/chain_repository.dart';
import '../../domain/repositories/identity_repository.dart';
import '../../domain/services/chain_manager.dart';
import '../../domain/services/face_matcher_service.dart';
import '../../domain/services/meeting_handshake_service.dart';
import '../../domain/use_cases/create_meeting_proof_use_case.dart';
import '../../domain/use_cases/ensure_local_identity_use_case.dart';
import '../../domain/use_cases/validate_chain_use_case.dart';
import '../../domain/use_cases/verify_meeting_proof_use_case.dart';
import '../crypto/ed25519_crypto_provider.dart';
import '../interfaces/crypto_provider.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({
  bool reset = false,
  bool enablePersistence = true,
  Isar? isarOverride,
  SecureKeyValueStore? secureStoreOverride,
}) async {
  if (reset) {
    await getIt.reset();
  }

  if (!getIt.isRegistered<CryptoProvider>()) {
    getIt.registerLazySingleton<CryptoProvider>(Ed25519CryptoProvider.new);
  }
  if (!getIt.isRegistered<MeetingHandshakeService>()) {
    getIt.registerLazySingleton<MeetingHandshakeService>(
      () => MeetingHandshakeService(getIt<CryptoProvider>()),
    );
  }
  if (!getIt.isRegistered<ChainManager>()) {
    getIt.registerLazySingleton<ChainManager>(
      () => ChainManager(getIt<CryptoProvider>()),
    );
  }
  if (!getIt.isRegistered<CreateMeetingProofUseCase>()) {
    getIt.registerLazySingleton<CreateMeetingProofUseCase>(
      () => CreateMeetingProofUseCase(getIt<MeetingHandshakeService>()),
    );
  }
  if (!getIt.isRegistered<VerifyMeetingProofUseCase>()) {
    getIt.registerLazySingleton<VerifyMeetingProofUseCase>(
      () => VerifyMeetingProofUseCase(getIt<CryptoProvider>()),
    );
  }
  if (!getIt.isRegistered<ValidateChainUseCase>()) {
    getIt.registerLazySingleton<ValidateChainUseCase>(
      () => ValidateChainUseCase(getIt<ChainManager>()),
    );
  }
  if (!getIt.isRegistered<FaceMatcherService>()) {
    getIt.registerLazySingleton<FaceMatcherService>(FaceMatcherService.new);
  }
  if (!getIt
      .isRegistered<BiometricScanner<BiometricScanRequest<CameraImage>>>()) {
    getIt.registerLazySingleton<
        BiometricScanner<BiometricScanRequest<CameraImage>>>(
      TfliteBiometricScanner.new,
    );
  }

  if (enablePersistence || isarOverride != null) {
    final isar = isarOverride ?? await _openIsarInstance();
    if (!getIt.isRegistered<Isar>()) {
      getIt.registerSingleton<Isar>(
        isar,
        dispose: (instance) async {
          if (instance.isOpen) {
            await instance.close();
          }
        },
      );
    }
  }

  if (enablePersistence || secureStoreOverride != null) {
    final secureStore = secureStoreOverride ?? FlutterSecureKeyValueStore();
    if (!getIt.isRegistered<SecureKeyValueStore>()) {
      getIt.registerLazySingleton<SecureKeyValueStore>(() => secureStore);
    }

    if (!getIt.isRegistered<IdentityRepository>()) {
      getIt.registerLazySingleton<IdentityRepository>(
        () => SecureIdentityRepository(getIt<SecureKeyValueStore>()),
      );
    }
  }

  if (getIt.isRegistered<Isar>() && !getIt.isRegistered<ChainRepository>()) {
    getIt.registerLazySingleton<ChainRepository>(
      () => IsarChainRepository(
        getIt<Isar>(),
        getIt<VerifyMeetingProofUseCase>(),
        getIt<CryptoProvider>(),
      ),
    );
  }

  if (getIt.isRegistered<IdentityRepository>() &&
      !getIt.isRegistered<EnsureLocalIdentityUseCase>()) {
    getIt.registerLazySingleton<EnsureLocalIdentityUseCase>(
      () => EnsureLocalIdentityUseCase(getIt<IdentityRepository>()),
    );
  }
}

Future<Isar> _openIsarInstance() async {
  final directory = await getApplicationDocumentsDirectory();
  return Isar.open(
    [MeetingProofModelSchema],
    directory: directory.path,
    name: 'malaqa',
  );
}
