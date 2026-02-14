# malaqa

Flutter + Dart core project for the `malaqa` decentralized meeting chain protocol.

## Scope (Phase 0 + Phase 1 Milestone G)

- Ed25519 identities and signatures
- Privacy-first face-vector salting + hashing
- Meeting proof creation and verification
- Chain validation across linked proofs
- Flutter mirror loop with camera preview and ML Kit face detection overlay
- Real TFLite biometric scanner flow (`Scan Me` -> vector + similarity)
- Secure local identity persistence via platform key stores
- Isar-based proof chain persistence with integrity validation

## Structure

- `lib/core/`: crypto interface, Ed25519 provider, identity
- `lib/data/`: device/data adapters
- `lib/domain/entities/`: `FaceVector`, `MeetingProof`, signatures, location
- `lib/domain/services/`: handshake, chain validation, face matching
- `lib/presentation/pages/mirror_page.dart`: camera mirror POC screen
- `lib/data/datasources/tflite_biometric_scanner.dart`: MobileFaceNet inference scanner
- `lib/core/utils/image_converter.dart`: camera frame conversion and preprocessing
- `lib/data/repositories/secure_identity_repository.dart`: secure identity storage
- `lib/data/repositories/isar_chain_repository.dart`: persistent proof chain storage
- `lib/data/models/meeting_proof_model.dart`: Isar DB model + mapping
- `test/magellan_core_test.dart`: TDD suite for core protocol behavior
- `bin/main.dart`: CLI simulation (Alice -> Bob -> Charlie)

## Run

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

For camera testing, run on a real Android/iOS device.

Model asset expected at:

`assets/models/mobilefacenet.tflite`
