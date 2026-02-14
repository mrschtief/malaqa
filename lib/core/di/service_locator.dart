import 'package:get_it/get_it.dart';

import '../../domain/services/chain_manager.dart';
import '../../domain/services/face_matcher_service.dart';
import '../../domain/services/meeting_handshake_service.dart';
import '../../domain/use_cases/create_meeting_proof_use_case.dart';
import '../../domain/use_cases/validate_chain_use_case.dart';
import '../../domain/use_cases/verify_meeting_proof_use_case.dart';
import '../crypto/ed25519_crypto_provider.dart';
import '../interfaces/crypto_provider.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({bool reset = false}) async {
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
}
