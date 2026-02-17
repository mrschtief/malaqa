import 'package:camera/camera.dart';
import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../services/app_settings_service.dart';
import '../../data/datasources/secure_key_value_store.dart';
import '../../data/datasources/tflite_biometric_scanner.dart';
import '../../data/datasources/nearby_service.dart';
import '../../data/datasources/device_location_provider.dart';
import '../../data/models/meeting_proof_model.dart';
import '../../data/repositories/isar_chain_repository.dart';
import '../../data/repositories/ipfs_repository.dart';
import '../../data/repositories/ethereum_anchor_repository.dart';
import '../../data/repositories/secure_identity_repository.dart';
import '../../domain/interfaces/biometric_scanner.dart';
import '../../domain/interfaces/location_provider.dart';
import '../../domain/gamification/badge_manager.dart';
import '../../domain/repositories/chain_repository.dart';
import '../../domain/repositories/identity_repository.dart';
import '../../domain/repositories/ipfs_repository.dart';
import '../../domain/repositories/anchor_repository.dart';
import '../../domain/services/chain_manager.dart';
import '../../domain/services/crypto_wallet_service.dart';
import '../../domain/services/decentralized_sync_service.dart';
import '../../domain/services/face_matcher_service.dart';
import '../../domain/services/meeting_handshake_service.dart';
import '../../domain/services/meeting_participant_resolver.dart';
import '../../domain/services/proof_importer.dart';
import '../../domain/services/statistics_service.dart';
import '../../domain/use_cases/create_meeting_proof_use_case.dart';
import '../../domain/use_cases/ensure_local_identity_use_case.dart';
import '../../domain/use_cases/validate_chain_use_case.dart';
import '../../domain/use_cases/verify_meeting_proof_use_case.dart';
import '../../presentation/blocs/auth/auth_cubit.dart';
import '../../presentation/blocs/journey/journey_cubit.dart';
import '../../presentation/blocs/map/map_cubit.dart';
import '../../presentation/blocs/meeting/meeting_cubit.dart';
import '../../presentation/blocs/proximity/proximity_cubit.dart';
import '../../presentation/blocs/profile/profile_cubit.dart';
import '../crypto/ed25519_crypto_provider.dart';
import '../interfaces/crypto_provider.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({
  bool reset = false,
  bool enablePersistence = true,
  Isar? isarOverride,
  SecureKeyValueStore? secureStoreOverride,
  AppSettingsService? appSettingsOverride,
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
  if (!getIt.isRegistered<NearbyService>()) {
    getIt.registerLazySingleton<NearbyService>(NearbyConnectionsService.new);
  }
  if (!getIt.isRegistered<LocationProvider>()) {
    getIt.registerLazySingleton<LocationProvider>(DeviceLocationProvider.new);
  }
  if (!getIt.isRegistered<MeetingParticipantResolver>()) {
    getIt.registerLazySingleton<MeetingParticipantResolver>(
      () => MeetingParticipantResolver(getIt<FaceMatcherService>()),
    );
  }
  if (!getIt.isRegistered<StatisticsService>()) {
    getIt.registerLazySingleton<StatisticsService>(StatisticsService.new);
  }
  if (!getIt.isRegistered<BadgeManager>()) {
    getIt.registerLazySingleton<BadgeManager>(
      () => BadgeManager(statisticsService: getIt<StatisticsService>()),
    );
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

  if (enablePersistence || appSettingsOverride != null) {
    final appSettings = appSettingsOverride ?? await AppSettingsService.load();
    if (!getIt.isRegistered<AppSettingsService>()) {
      getIt.registerSingleton<AppSettingsService>(appSettings);
    }
  }

  if (getIt.isRegistered<IdentityRepository>() &&
      getIt.isRegistered<CryptoProvider>() &&
      !getIt.isRegistered<CryptoWalletService>()) {
    getIt.registerLazySingleton<CryptoWalletService>(
      () => CryptoWalletService(
        identityRepository: getIt<IdentityRepository>(),
        crypto: getIt<CryptoProvider>(),
      ),
    );
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

  if (!getIt.isRegistered<IpfsRepository>()) {
    getIt.registerLazySingleton<IpfsRepository>(HttpIpfsRepository.new);
  }

  if (getIt.isRegistered<ChainRepository>() &&
      getIt.isRegistered<IpfsRepository>() &&
      !getIt.isRegistered<DecentralizedSyncService>()) {
    getIt.registerLazySingleton<DecentralizedSyncService>(
      () => DecentralizedSyncService(
        chainRepository: getIt<ChainRepository>(),
        ipfsRepository: getIt<IpfsRepository>(),
      ),
    );
  }

  if (getIt.isRegistered<CryptoWalletService>() &&
      !getIt.isRegistered<AnchorRepository>()) {
    getIt.registerLazySingleton<AnchorRepository>(
      () => EthereumAnchorRepository(
        rpcUrl: 'http://127.0.0.1:8545',
        walletService: getIt<CryptoWalletService>(),
        simulateOnly: true,
      ),
    );
  }

  if (getIt.isRegistered<ChainRepository>() &&
      getIt.isRegistered<VerifyMeetingProofUseCase>() &&
      getIt.isRegistered<CryptoProvider>() &&
      !getIt.isRegistered<ProofImporter>()) {
    getIt.registerLazySingleton<ProofImporter>(
      () => ProofImporter(
        chainRepository: getIt<ChainRepository>(),
        verifyProofUseCase: getIt<VerifyMeetingProofUseCase>(),
        crypto: getIt<CryptoProvider>(),
      ),
    );
  }

  if (getIt.isRegistered<IdentityRepository>() &&
      !getIt.isRegistered<EnsureLocalIdentityUseCase>()) {
    getIt.registerLazySingleton<EnsureLocalIdentityUseCase>(
      () => EnsureLocalIdentityUseCase(getIt<IdentityRepository>()),
    );
  }

  if (getIt.isRegistered<IdentityRepository>() &&
      !getIt.isRegistered<AuthCubit>()) {
    getIt.registerFactory<AuthCubit>(
      () => AuthCubit(
        identityRepository: getIt<IdentityRepository>(),
        scanner: getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>(),
        faceMatcher: getIt<FaceMatcherService>(),
      ),
    );
  }

  if (getIt.isRegistered<IdentityRepository>() &&
      getIt.isRegistered<ChainRepository>() &&
      !getIt.isRegistered<MeetingCubit>()) {
    getIt.registerFactory<MeetingCubit>(
      () => MeetingCubit(
        scanner: getIt<BiometricScanner<BiometricScanRequest<CameraImage>>>(),
        participantResolver: getIt<MeetingParticipantResolver>(),
        handshakeService: getIt<MeetingHandshakeService>(),
        chainRepository: getIt<ChainRepository>(),
        crypto: getIt<CryptoProvider>(),
        locationProvider: getIt<LocationProvider>(),
      ),
    );
  }

  if (getIt.isRegistered<ChainRepository>() &&
      !getIt.isRegistered<JourneyCubit>()) {
    getIt.registerFactory<JourneyCubit>(
      () => JourneyCubit(getIt<ChainRepository>()),
    );
  }

  if (getIt.isRegistered<ChainRepository>() &&
      !getIt.isRegistered<MapCubit>()) {
    getIt.registerFactory<MapCubit>(
      () => MapCubit(getIt<ChainRepository>()),
    );
  }

  if (getIt.isRegistered<IdentityRepository>() &&
      getIt.isRegistered<ChainRepository>() &&
      !getIt.isRegistered<ProfileCubit>()) {
    getIt.registerFactory<ProfileCubit>(
      () => ProfileCubit(
        identityRepository: getIt<IdentityRepository>(),
        chainRepository: getIt<ChainRepository>(),
        statisticsService: getIt<StatisticsService>(),
        badgeManager: getIt<BadgeManager>(),
      ),
    );
  }

  if (getIt.isRegistered<ProofImporter>() &&
      getIt.isRegistered<NearbyService>() &&
      getIt.isRegistered<CryptoProvider>() &&
      getIt.isRegistered<FaceMatcherService>() &&
      !getIt.isRegistered<ProximityCubit>()) {
    getIt.registerFactory<ProximityCubit>(
      () => ProximityCubit(
        nearbyService: getIt<NearbyService>(),
        proofImporter: getIt<ProofImporter>(),
        faceMatcher: getIt<FaceMatcherService>(),
        crypto: getIt<CryptoProvider>(),
      ),
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
