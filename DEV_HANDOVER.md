# DEV_HANDOVER.md

End-of-day handover for next session (Day 2 cold start).

Date: 2026-02-14
Repo: `malaqa`
Branch: `main`

## 1. System Status

### Production-ready modules (local reliability)

- Core protocol and crypto:
  - Ed25519 identity management
  - canonical proof payload/hash/signature validation
  - chain linkage validation
- Auth + capture loop:
  - Magic Mirror auth
  - owner/guest duo scan
  - liveness challenge gate
- Local data integrity:
  - Isar proof persistence
  - integrity checks on load (signature + recomputed proof hash)
  - secure identity/key storage
- UX layers:
  - Journey timeline
  - World map
  - Profile + badges/stats
  - Onboarding + Settings + reset flow
- Transfer logic:
  - QR import/export
  - proximity payload matching + claim flow

### Mock/simulation modules (not yet true network production)

- IPFS bridge:
  - local CID generation is real
  - sync orchestration is real
  - remote upload currently simulation-first (HTTP path prepared)
- Blockchain anchor:
  - transaction building/signing is real and tested
  - broadcasting to public chain currently simulation/mock sender
  - no deployed production contract wired yet

## 2. Critical Workarounds

### Android `minSdkVersion = 23`

- Required in `android/app/build.gradle.kts` for current plugin set compatibility (camera + nearby + permissions stack).
- Keep this pinned unless all involved plugins are revalidated at lower API levels.

### Canonical proof stability (CID must not mutate signatures)

- `MeetingProof.canonicalPayload()` and `MeetingProof.canonicalJson()` are intentionally independent from `ipfsCid`.
- `ipfsCid` is metadata added after proof creation/signing.
- Reason: including CID in signed/canonical payload would change hash/signature validity and break proof integrity.

## 3. Known Ghosts (Unverified on real hardware)

- Full device E2E across permission edge-cases:
  - camera + location + bluetooth request sequencing during first-run onboarding
- Android manifest merge behavior across all active plugins on multiple OEM devices.
- iOS runtime behavior for combined camera/nearby/location permission prompts.
- Long-running Nearby discovery/advertising battery impact and lifecycle resilience.
- Real chain/network behavior:
  - IPFS pinning endpoint responses
  - Polygon/Amoy transaction propagation + nonce/gas handling

## 4. Next Steps (Day 2)

1. Phase 5 polish:
   - UX/performance pass (camera loop smoothness, animation pacing, messaging clarity)
   - integrate explicit biometric re-check (`local_auth`) for backup phrase reveal
   - settings refinement and permission fallback UX
2. Real decentralized activation:
   - wire real IPFS endpoint (Pinata/Infura/etc.) behind env-config
   - deploy minimal contract (`storeHash(bytes32)`) on testnet
   - switch anchor repository from simulate to real send on test profile
3. Hardware test matrix:
   - Android: at least 2 devices + 1 emulator sanity
   - iOS: at least 1 physical device
   - capture known issues with reproducible steps

## 5. Personal Log (Codex)

- Komplexeste technische Hürde heute:
  - Die durchgehende Orchestrierung über viele Schichten (Kamera, Liveness, P2P, Isar, IPFS/Anchor) bei gleichzeitig stabiler Testbarkeit ohne permanente Hardware-Abhängigkeit.
- Wichtigste Architektur-Entscheidung:
  - Die strikte Trennung zwischen signiertem Proof-Kern und nachgelagerter Metadatenebene (`ipfsCid`/Anchoring), plus wiederverwendbare Import-/Envelope-Pfade für mehrere Transportkanäle.
- Größtes Risiko für morgen:
  - Unterschiede zwischen headless/tests und realen Geräten (Permissions, plugin lifecycles, manifest/plist interactions) können trotz grüner Tests noch produktionsrelevante Brüche verursachen.
