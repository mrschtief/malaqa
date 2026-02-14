# malaqa

`malaqa` is an offline-first, privacy-first mobile protocol for verifiable human encounters.

## Current Feature Set

- Magic Mirror Auth (camera-first, zero-click owner recognition)
- Duo meeting capture (owner + guest detection in one frame)
- Liveness guard (smile/blink challenge to reduce spoofing)
- Cryptographic proof chain (signed `MeetingProof` links)
- Local persistence with integrity checks (Isar + proof hash validation)
- Journey timeline + world map visualization
- Profile stats + badge gamification
- QR fallback bridge for manual proof transfer
- Nearby P2P mesh flow for automatic proximity claim
- IPFS bridge (local CID computation + sync orchestration)
- Blockchain anchor layer (offline Ethereum tx signing, simulation mode)
- First-run onboarding + settings vault (nearby visibility, reset, backup reveal)

## Architecture

- `lib/core/`: crypto primitives, identity, DI, settings primitives
- `lib/domain/`: entities, repositories, services, protocol rules
- `lib/data/`: hardware/storage/network adapters
- `lib/presentation/`: app shell, pages, cubits, UX flows
- `test/`: unit + integration verification suite

## Tech Stack

- Flutter / Dart
- Camera + ML Kit + TensorFlow Lite
- Isar (`isar`, `isar_flutter_libs`)
- Secure storage (`flutter_secure_storage`)
- Maps (`flutter_map`, `latlong2`, OpenStreetMap tiles)
- P2P (`nearby_connections`, QR fallback via `qr_flutter` + `mobile_scanner`)
- Crypto (`cryptography`, Ed25519/SHA-256)
- Web3 (`web3dart`, `bip39`)
- Sync bridge (`http`, `cid`)

## Quick Start

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

## Requirements / Notes

- Recommended device testing on physical Android/iOS hardware.
- Android config currently requires `minSdkVersion 23`.
- Model expected at `assets/models/mobilefacenet.tflite`.
- Main planning and status: `MALAQA.md`.
- Session protocol and execution rules: `AGENTS.md`.
