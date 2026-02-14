# malaqa

Flutter + Dart core project for the `malaqa` decentralized meeting chain protocol.

## Scope (Phase 0 + Phase 1 Milestone E)

- Ed25519 identities and signatures
- Privacy-first face-vector salting + hashing
- Meeting proof creation and verification
- Chain validation across linked proofs
- Flutter mirror loop with camera preview and ML Kit face detection overlay
- Dummy camera biometric scanner flow (`Scan Me` -> vector generated)

## Structure

- `lib/core/`: crypto interface, Ed25519 provider, identity
- `lib/data/`: device/data adapters
- `lib/domain/entities/`: `FaceVector`, `MeetingProof`, signatures, location
- `lib/domain/services/`: handshake, chain validation, face matching
- `lib/presentation/pages/mirror_page.dart`: camera mirror POC screen
- `test/magellan_core_test.dart`: TDD suite for core protocol behavior
- `bin/main.dart`: CLI simulation (Alice -> Bob -> Charlie)

## Run

```bash
flutter pub get
flutter test
flutter run
```

For camera testing, run on a real Android/iOS device.
