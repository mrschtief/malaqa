# malaqa

Flutter + Dart core project for the `malaqa` decentralized meeting chain protocol.

## Scope (Phase 0)

- Ed25519 identities and signatures
- Privacy-first face-vector salting + hashing
- Meeting proof creation and verification
- Chain validation across linked proofs

## Structure

- `lib/core/`: crypto interface, Ed25519 provider, identity
- `lib/domain/entities/`: `FaceVector`, `MeetingProof`, signatures, location
- `lib/domain/services/`: handshake creation and chain validation
- `test/magellan_core_test.dart`: TDD suite for core protocol behavior
- `bin/main.dart`: CLI simulation (Alice -> Bob -> Charlie)

## Run

```bash
flutter pub get
flutter test
flutter run
```
