# MALAQA

Masterplan und lebende Projektdokumentation fuer das dezentrale Begegnungsprotokoll `malaqa` (ehemals Arbeitsname "Magellan").

## 1. Vision

`malaqa` ist ein Offline-First, Privacy-First Protokoll fuer verifizierbare menschliche Begegnungen:

- Person A trifft Person B
- Gemeinsamer kryptografischer Proof of Meeting
- B trifft C
- Die Kette waechst ohne zentrale Bilddatenbank

Ziele:

- Keine zentral gespeicherten Gesichter/Fotos
- Verifikation durch Signaturen und Kettenhashes
- Schrittweise Evolution von lokaler Logik zu dezentraler Synchronisierung

## 2. Leitprinzipien

- Offline-first: Kernfunktionen muessen ohne Internet laufen.
- Privacy-first: Keine rohen Biometrics persistent speichern.
- Cryptography-first: Integritaet ueber Signaturen und Hash-Verkettung.
- Clean Architecture: Klare Schichten und testbare Grenzen.
- TDD: Erst Test, dann Implementierung.

## 3. Architektur (aktuell)

Repository-Layers:

- `lib/core/`: Krypto-Interfaces, Ed25519/SHA-256 Provider, Identity.
- `lib/data/`: Adapter fuer Kamera/IO und spaetere Persistenz/Netzwerkquellen.
- `lib/domain/entities/`: `FaceVector`, `MeetingProof`, `LocationPoint`, `ParticipantSignature`.
- `lib/domain/services/`: Handshake, Chain und Face-Matching Logik.
- `test/`: Kernlogik-Tests.
- `bin/`: Laufbare CLI-Demo.

## 4. Was bereits umgesetzt ist (Stand: 14. Februar 2026)

### Phase 0: Pure Dart Core Logic

Status: `abgeschlossen (MVP fuer Kernlogik)`

Umgesetzt:

- Ed25519 Identity-Objekt mit internem Private Key.
- Salting + Hashing fuer Face-Vectors (Privacy-Schutz gegen triviales Tracking).
- `MeetingProof` mit:
  - `timestamp` (ISO8601)
  - `location` (lat/lon)
  - `saltedVectorHash`
  - `previousMeetingHash`
  - zwei Teilnehmer-Signaturen
- `verifyProof()` prueft:
  - Signaturintegritaet
  - Feldvaliditaet (Zeit, Hash-Format, Koordinaten)
- `ChainManager.isValidChain(...)` prueft:
  - Genesis-Regel (`previousMeetingHash == "0000"`)
  - korrekte Hash-Referenz auf den Vorgaenger
  - gueltige Proofs pro Kettenglied
- Tests:
  - valider Alice/Bob-Handshake
  - Manipulation von Zeit/Ort invalidiert Proof
  - valide 5-Personen-Kette
- CLI-Demo:
  - Alice -> Bob -> Charlie
  - Chain-Validierung in Konsole

### Milestone A: API-Haertung fuer MeetingProof

Status: `abgeschlossen`

Umgesetzt:

- `toJson/fromJson` fuer:
  - `MeetingProof`
  - `LocationPoint`
  - `ParticipantSignature`
- JSON-Roundtrip-Test fuer `MeetingProof` (inkl. Signatur-Verifizierbarkeit nach Roundtrip).
- Deterministische kanonische Encodierung:
  - `canonicalProof()`
  - `canonicalJson()`
  - stabil bei unterschiedlicher Signatur-Reihenfolge.

### Milestone B: Domain UseCases als explizite Klassen

Status: `abgeschlossen`

Umgesetzt:

- Neue UseCases:
  - `CreateMeetingProofUseCase`
  - `VerifyMeetingProofUseCase`
  - `ValidateChainUseCase`
- Eigene Test-Suite `test/domain_use_cases_test.dart` mit:
  - validem Create+Verify Flow
  - Manipulationsfall fuer Verify
  - validierter und gebrochener Chain-Fall fuer Validate

### Milestone C: Flutter Integration (Infrastruktur)

Status: `abgeschlossen`

Umgesetzt:

- Projekt auf Flutter-Toolchain erweitert (`flutter`/`flutter_test` in `pubspec.yaml`).
- Minimaler Flutter-App-Entry erstellt:
  - `lib/main.dart`
  - `lib/presentation/app/malaqa_app.dart`
- Clean-Architecture Zielstruktur fuer naechste Phasen angelegt:
  - `lib/presentation/`
  - `lib/data/`
- Dependency Injection mit `get_it` eingefuehrt:
  - `lib/core/di/service_locator.dart`
  - zentrale Registrierungen als Lazy Singletons fuer Core-/Domain-Services.
- DI-Integration testseitig abgesichert:
  - `test/service_locator_test.dart`

### Milestone D: FaceMatcher Domain Logic

Status: `abgeschlossen`

Umgesetzt:

- `FaceMatcherService` mit Cosine Similarity:
  - `compare(FaceVector v1, FaceVector v2)`
  - `isMatch(FaceVector v1, FaceVector v2, {double threshold = 0.8})`
  - robust gegen Nullvektor und numerische Grenzfaelle.
- TDD-Testabdeckung fuer FaceMatcher:
  - identische Vektoren -> ~1.0
  - orthogonale Vektoren -> ~0.0
  - aehnliche Vektoren -> hoher Score
  - Nullvektor-Fall -> 0.0
  - Datei: `test/face_matcher_service_test.dart`
- Hardware-Abstraktion fuer spaetere Kamera/ML-Adapter:
  - `lib/domain/interfaces/biometric_scanner.dart`

### Milestone E: Mirror Loop (Kamera + Real-Time Detection Pipeline)

Status: `abgeschlossen`

Umgesetzt:

- Flutter-Projektplattformen fuer Mobile initialisiert:
  - `android/`
  - `ios/`
- Kamera- und Detection-Dependencies integriert:
  - `camera`
  - `google_mlkit_face_detection`
  - `permission_handler`
- Presentation-Layer fuer Mirror POC:
  - `lib/presentation/pages/mirror_page.dart`
  - Vollbild-Kamera-Preview
  - Face Bounding Box Overlay
  - Button `Scan Me`
  - Statusanzeige (`Similarity: 0.0` Basisfluss)
- Data-Layer Scanner-Implementierung:
  - `lib/data/datasources/camera_biometric_scanner.dart`
  - implementiert `BiometricScanner<CameraImage>`
  - liefert fuer Milestone E einen Dummy-Embedding-Vector (512)
  - markierter TODO fuer spaeteren TFLite-Inference-Call
- DI-Wiring fuer Scanner:
  - Registrierung als Lazy Singleton in `lib/core/di/service_locator.dart`
- App-Wiring:
  - `lib/presentation/app/malaqa_app.dart` zeigt jetzt `MirrorPage`
- Mobile Permissions gesetzt:
  - Android: `android/app/src/main/AndroidManifest.xml` mit `CAMERA`
  - iOS: `ios/Runner/Info.plist` mit `NSCameraUsageDescription`

### Implementierungsstand nach Modulen (Detail)

`lib/core/`:

- `lib/core/interfaces/crypto_provider.dart`: Interface fuer Random, Hash, Signatur, Verifikation ist vorhanden und stabil.
- `lib/core/crypto/ed25519_crypto_provider.dart`: konkrete Implementierung fuer Ed25519 + SHA-256 + Utility-Funktionen ist umgesetzt.
- `lib/core/identity.dart`: Key-Pair-Erzeugung und Signieren ueber gekapselten Private Key ist umgesetzt.
- `lib/core/di/service_locator.dart`: DI-Setup mit Lazy Singletons inkl. Camera Scanner Registrierung ist umgesetzt.

`lib/data/`:

- `lib/data/datasources/camera_biometric_scanner.dart`: Kamera-Frame zu Dummy-Embedding Pipeline (TFLite-ready Skeleton) ist umgesetzt.

`lib/domain/entities/`:

- `lib/domain/entities/face_vector.dart`: Face-Vector Wrapper + Salted Hash vorhanden.
- `lib/domain/entities/location_point.dart`: Entitaet, Canonical String und JSON Roundtrip vorhanden.
- `lib/domain/entities/participant_signature.dart`: Entitaet, Canonical String und JSON Roundtrip vorhanden.
- `lib/domain/entities/meeting_proof.dart`: Payload/Proof Canonicalisierung, Hash-Bildung, Signaturpruefung und JSON Roundtrip vorhanden.

`lib/domain/services/`:

- `lib/domain/services/meeting_handshake_service.dart`: Erstellung eines signierten Proofs fuer zwei Teilnehmer umgesetzt.
- `lib/domain/services/chain_manager.dart`: Genesis-Regel + Link-Validierung + Proof-Validierung fuer die gesamte Kette umgesetzt.
- `lib/domain/services/face_matcher_service.dart`: Cosine Similarity und Match-Entscheidung umgesetzt.

`lib/domain/interfaces/`:

- `lib/domain/interfaces/biometric_scanner.dart`: generisches Scanner-Interface als Adaptergrenze vorhanden.

`lib/domain/use_cases/`:

- `lib/domain/use_cases/create_meeting_proof_use_case.dart`: vorhanden.
- `lib/domain/use_cases/verify_meeting_proof_use_case.dart`: vorhanden.
- `lib/domain/use_cases/validate_chain_use_case.dart`: vorhanden.

`test/`:

- `test/magellan_core_test.dart`: Phase-0 Kernlogik sowie Milestone-A-Tests vorhanden.
- `test/domain_use_cases_test.dart`: Milestone-B UseCase-Tests vorhanden.
- `test/face_matcher_service_test.dart`: Milestone-D Mathematik- und Schwellwerttests vorhanden.
- `test/service_locator_test.dart`: Milestone-C DI-Registrierung und Lazy-Singleton-Verhalten vorhanden.
- `test/widget_test.dart`: Flutter Test-Skeleton vorhanden.

`platform`:

- `android/`: lauffaehiges Android Flutter Projekt inklusive Camera Permission.
- `ios/`: lauffaehiges iOS Flutter Projekt inklusive Camera Usage Description.

`bin/`:

- `bin/main.dart`: End-to-End Konsolenfluss fuer kurze manuelle Verifikation vorhanden.

## 5. Zielarchitektur (Roadmap)

### Phase 1: Mirror POC (Flutter + On-Device Face Pipeline)

Ziel:

- Kamera auf
- Gesicht erkennen
- Embedding erzeugen
- lokaler Vergleich (gleiche Person vs. andere Person)

Lieferobjekte:

- Flutter App Skeleton
- Face Adapter Interface (Model austauschbar)
- Demo-UI fuer Vektorvergleich

### Phase 2: Handshake Local Multiplayer

Ziel:

- Proof-Exchange zwischen zwei Geraeten lokal

Lieferobjekte:

- QR fuer Session/Identity Austausch
- lokaler Datentransfer (zuerst einfach, spaeter robust)
- beidseitige Signaturbestaetigung

### Phase 3: Local Chain Storage + Views

Ziel:

- Lokale Speicherung und Darstellung der Kette

Lieferobjekte:

- Persistenzadapter (z. B. Isar)
- Timeline/Graph Ansicht
- lokale Kartenpins

### Phase 4: Dezentrale Synchronisierung

Ziel:

- selektiver Austausch verschluesselter Proof-Artefakte

Lieferobjekte:

- Content-addressed Storage Integration
- encrypted payload distribution
- conflict und merge Regeln fuer Chain-Fortschritt

### Phase 5: Security Hardening

Ziel:

- Schutz gegen Spoofing und manipulative Clients

Lieferobjekte:

- Liveness-Checks
- Device Integrity Checks
- optionales On-Chain Notariat fuer Root-Hashes

## 6. Entscheidungen und offene Punkte

Bereits entschieden:

- Projektname: `malaqa`.
- Start mit reiner Dart-Corelogik vor UI.
- Ed25519 + SHA-256 als erster Kryptostack.

Offen und konkret noch zu bauen:

`Phase 1 / Flutter-Grundgeruest`:

- Routing/App-Navigation aufbauen (aktuell nur Minimal-App-Entry).
- Erstes State-Management fuer Feature-Flow festlegen und integrieren.
- CI-Lauf fuer `flutter test` + Format/Lints etablieren.

`Phase 1 / Face Pipeline`:

- ML Kit Detection aus `MirrorPage` in einen separaten Data Adapter extrahieren.
- Echten Embedding-Extractor per TFLite (MobileFaceNet) implementieren.
- `Scan Me` mit echter Vergleichslogik gegen gespeicherten Referenzvektor verdrahten.

`Phase 2 / Lokaler Handshake ueber zwei Geraete`:

- Session-Aufbau ueber QR definieren.
- Transportkanal fuer lokale Uebertragung integrieren.
- Bestaetigungs- und Fehlerzustaende (Timeout, Abbruch, Retry) modellieren.

`Phase 3 / Lokale Persistenz und Visualisierung`:

- Persistenzschema fuer Proofs festlegen.
- Repository-Layer fuer Schreiben/Lesen der Chain implementieren.
- Timeline/Graph Darstellung in der App aufbauen.

`Security-Haertung`:

- Liveness-Konzept konkretisieren und in Interfaces giesen.
- Schluesselrotation und DID-Lifecycle spezifizieren.
- Replay-Schutz und Rate-Limits fuer Handshake-Flows definieren.

`Testabdeckung (fachlich offen)`:

- Property-basierte Tests fuer Canonicalisierung und Hash-Konsistenz.
- Negativtests fuer kaputte JSON-Payloads und unvollstaendige Signatur-Sets.
- Performance-Budgets fuer mobile Zielgeraete definieren und messen.

## 7. Arbeitsmodus fuer die naechsten Schritte

Standard-Iteration:

1. Ein kleines Ziel definieren.
2. Testfall schreiben (rot).
3. Implementieren (gruen).
4. Refactoring + Dokumentation.
5. Commit mit sauberem Scope.

Definition of Done pro Schritt:

- Tests gruen
- relevante Doku in `MALAQA.md` aktualisiert
- Changelog/Commit nachvollziehbar

## 8. Vorschlag fuer konkrete naechste Milestones

Milestone A:

- `abgeschlossen` API-Haertung fuer `MeetingProof` Serialisierung (JSON roundtrip + canonical encoding tests).

Milestone B:

- `abgeschlossen` Domain-UseCases als explizite Klassen (CreateMeetingProof, VerifyMeetingProof, ValidateChain).

Milestone C:

- `abgeschlossen` Flutter-App initialisieren und Core-Library als Abhaengigkeit einbinden.

Milestone D:

- `abgeschlossen` FaceMatcher (Cosine Similarity) als eigenstaendige, getestete Domain-Komponente.

Milestone E:

- `abgeschlossen` Mirror Loop (Kamera-Preview, Face Detection Overlay, Scanner-Wiring, Permission Setup).

Milestone F:

- Persistenzadapter fuer lokale Chain-Speicherung mit Integritaetschecks.

---

Diese Datei ist der Masterplan. Operative Agenten-/Workflow-Regeln stehen in `AGENTS.md`.
