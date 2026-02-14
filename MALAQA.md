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

### Vision Reset: Spiel + Sinn

`malaqa` ist nicht nur eine sichere Datenpipeline, sondern ein soziales Spiel mit echter Bedeutung:

- Spielkern: Ein viraler Staffelstab. Ich starte eine Kette, uebergebe sie per gemeinsamer Aufnahme, und die Kette reist ohne mich weiter.
- Belohnung: Spaeteres Wiedersehen ueber die Kette (z. B. neue Stationen, Distanz, Kontinente, Connector-Rollen).
- Produktgefuehl: "Magic Moment" statt Formular-Flow. Technik bleibt im Hintergrund, Begegnung steht im Vordergrund.

Das grosse Ziel bleibt ein Privacy-First "Web of Trust":

- Gegenmittel zu Bots/Deepfakes durch kryptografisch belegte reale Begegnungen.
- Kein zentraler Betreiber, kein zentraler Bildpool, kein Plattform-Lock-in.
- Sichtbarkeit wird abgestuft gedacht (Trust Circles/Radien), damit Neugier und Datenschutz zusammenpassen.

UX-Leitstern fuer die naechsten Phasen:

- Camera-first Einstieg.
- Reibungsarme Owner+Guest-Erkennung fuer Duo-Selfies.
- Begegnung fuehlt sich wie ein Pakt an, nicht wie Registrierung.

### Vision Reset: Magic Mirror Auth

Die App-Eingangstuer ist jetzt als "biometrischer Spiegel" gedacht:

- Zero-Click Login: Start direkt in die Kamera, kein E-Mail/Passwort.
- Die App sucht den Owner im Hintergrund und entsperrt automatisch bei Match.
- Das Entsperren fuehlt sich physisch an (Haptic Feedback) und blendet die Controls weich ein.
- Setup-Fall bleibt reibungsarm:
  - Kein vorhandenes Profil -> "Create Identity & Start Journey"
  - erster gueltiger Face-Scan wird als lokales Owner-Template gespeichert.

Produktziel:

- Technik bleibt unsichtbar (Kamera/ML/Krypto laufen im Hintergrund).
- Vordergrund ist das Erlebnis: Begegnung, Staffelstab, lebendige Kette.

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
- DI-Wiring fuer Scanner:
  - Registrierung als Lazy Singleton in `lib/core/di/service_locator.dart`
- App-Wiring:
  - `lib/presentation/app/malaqa_app.dart` zeigt jetzt `MirrorPage`
- Mobile Permissions gesetzt:
  - Android: `android/app/src/main/AndroidManifest.xml` mit `CAMERA`
  - iOS: `ios/Runner/Info.plist` mit `NSCameraUsageDescription`

### Milestone F: Real TFLite Integration (MobileFaceNet)

Status: `abgeschlossen`

Umgesetzt:

- Neue Dependencies:
  - `tflite_flutter`
  - `image`
- Modell-Asset registriert:
  - `assets/models/mobilefacenet.tflite` in `pubspec.yaml`
- Bildkonvertierung + Preprocessing:
  - `lib/core/utils/image_converter.dart`
  - YUV420/BGRA8888 -> RGB
  - Rotation angewandt
  - Crop via Face Bounding Box
  - Resize auf 112x112
  - Normalisierung `(pixel - 128) / 128.0`
- Echter TFLite Scanner:
  - `lib/data/datasources/tflite_biometric_scanner.dart`
  - lazy Interpreter Load via `Interpreter.fromAsset(...)`
  - `InterpreterOptions` mit `threads = 4`
  - Inferenz-Output wird zu `FaceVector` gemappt
- Domain Interface erweitert:
  - `BiometricScanRequest<TImage>` + `FaceBounds`
  - Scanner verarbeitet jetzt Bild + Bounding Box + Rotation
- Mirror-Flow erweitert:
  - 1. Klick: Referenzvektor A speichern
  - 2. Klick: Vektor B erfassen und Similarity via `FaceMatcherService` berechnen
  - UI zeigt den Similarity-Score inkl. Match-Ergebnis
- Tests:
  - `test/image_converter_test.dart` fuer Preprocessing (Laenge + Normalisierung)

### Milestone G: Persistence & Secure Storage

Status: `abgeschlossen`

Umgesetzt:

- Neue Dependencies:
  - `flutter_secure_storage`
  - `isar`
  - `isar_flutter_libs`
  - `path_provider`
  - `build_runner` + `isar_generator` (dev)
- Secure Identity Storage:
  - Domain Interface: `lib/domain/repositories/identity_repository.dart`
  - Implementation: `lib/data/repositories/secure_identity_repository.dart`
  - Key-Value Adapter: `lib/data/datasources/secure_key_value_store.dart`
  - Private Key Bytes werden in `flutter_secure_storage` persistiert.
  - Identity wird aus gespeicherten Key-Bytes rehydriert.
- Chain Storage mit Isar:
  - Isar Model: `lib/data/models/meeting_proof_model.dart`
  - Codegen: `lib/data/models/meeting_proof_model.g.dart`
  - Repository Interface: `lib/domain/repositories/chain_repository.dart`
  - Repository Implementation: `lib/data/repositories/isar_chain_repository.dart`
  - Integritaetscheck beim Laden:
    - Signatur-Validierung
    - Re-Hash gegen gespeicherten `proofHash`
- Async DI Wiring:
  - `lib/core/di/service_locator.dart` oeffnet `Isar` asynchron.
  - Repositories werden im DI-Container registriert.
- App Startup:
  - `lib/main.dart` ruft `EnsureLocalIdentityUseCase` vor `runApp()` auf.
  - Erste App-Ausfuehrung erzeugt lokale Identity und speichert sie sicher.
  - Folgestarts laden dieselbe Identity wieder.
- Tests:
- `test/secure_identity_repository_test.dart`
- `test/isar_chain_repository_test.dart`
- `test/image_converter_test.dart`
- Alle bestehenden Tests bleiben gruen.

### Milestone G-2: Headless Logic Verification

Status: `abgeschlossen`

Umgesetzt:

- `AppLogger` als gemeinsame Debug/Test-Logging-Infrastruktur.
- Logger-Integration in kritische Flows:
  - Identity Save/Load
  - Meeting Handshake
  - Isar Persistenz/Reload
  - Bootstrap-UseCase fuer lokale Identity
- Headless Systemtest mit echtem Kern:
  - echte Isar in Temp-Directory
  - echte UseCases/Repositories/Signaturen
  - gemockte Hardware-Raender (Scanner + Secure Store)
  - Roundtrip: Scan -> Proof -> Save -> Reboot -> Load -> Verify.

Ergebnis:

- Vollstaendige, automatisierte End-to-End-Pruefung der Kernlogik ohne Emulator/Geraet.
- Detaillierte, assertbare Ablauf-Logs aus dem Testlauf.

### Milestone G-3: Multi-Face Domain Upgrade

Status: `abgeschlossen`

Umgesetzt:

- Scanner-Schnittstelle auf Multi-Face erweitert:
  - `scanFaces(...)` in `BiometricScanner`.
- TFLite-Adapter kann mehrere Face-Bounds in einem Frame verarbeiten.
- Neuer Domain-Service:
  - `MeetingParticipantResolver`
  - ordnet erkannte Vektoren in `owner` und `guest` ein.
- Headless Roundtrip-Test erweitert:
  - explizite Duo-Erkennung (Owner+Guest) vor Proof-Erzeugung.
- Zusaeztliche Resolver-Unit-Tests fuer positive/negative Zuordnung.

### Milestone H: Seamless Face Auth (Magic Mirror)

Status: `abgeschlossen (erste produktnahe Version)`

Umgesetzt:

- Neues State-Management fuer Face-Auth:
  - `AuthCubit` + Zustandsmodell (`Initial`, `Setup`, `Scanning`, `Authenticated`, `Locked`)
  - Debounce/Throttle in der Scan-Logik (500ms Intervall) zur CPU/Batterie-Entlastung.
- Persistenter Owner-Template-Speicher:
  - `IdentityRepository` erweitert um Save/Load fuer Owner Face Vector.
  - `SecureIdentityRepository` persistiert den Vektor in Secure Storage.
- Neue camera-first Seite:
  - `AuthPage` als neuer Startscreen.
  - Vollbildkamera + lebender Face-Reticle.
  - Setup-Button fuer Erstnutzer.
  - Auto-Auth bei Match ohne Button.
  - Haptic + System-Click bei erfolgreichem Unlock.
- UI-Freischaltung nach Auth:
  - `Capture Moment` Call-to-Action (placeholder)
  - Map-Shortcut (placeholder)
  - Profilindikator oben rechts.
- App-Wiring:
  - `MalaqaApp` nutzt `BlocProvider` fuer `AuthCubit`.
  - `AuthPage` ist neue `home`.
- Tests erweitert:
  - neuer `auth_cubit_test.dart`
  - `secure_identity_repository_test.dart` um Owner-Vector Roundtrip erweitert.

### Milestone I: The Meeting Capture

Status: `abgeschlossen (MVP)`

Umgesetzt:

- Neuer `MeetingCubit` fuer den Begegnungs-Flow:
  - `MeetingIdle`, `MeetingReady`, `MeetingCapturing`, `MeetingSuccess`, `MeetingError`
  - framebasierte Owner/Guest-Erkennung im authentifizierten Zustand
  - persistente Proof-Erzeugung mit lokaler Kettenfortsetzung.
- `AuthPage` erweitert:
  - zweites Gast-Reticle (Cyan)
  - Capture-Button glowt/pulsiert nur in `MeetingReady`
  - Success-Card als Bottom Sheet nach erfolgreichem Capture.
- Datenfluss:
  - `MeetingParticipantResolver` liefert jetzt auch Owner/Gast-Indizes zur UI-Zuordnung.
  - bei Capture wird ein Proof gespeichert und die Chain lokal verlaengert.
- MVP-Limitation explizit:
  - Gast-Signatur wird lokal ueber einen Placeholder-Key simuliert,
    bis echter P2P-Handshake (beidseitige Signatur) in Phase 2 voll integriert ist.
- Tests erweitert:
  - neuer `meeting_cubit_test.dart`.

### Milestone J: The Journey Timeline (Denkarium)

Status: `abgeschlossen (MVP)`

Umgesetzt:

- Neues Journey State-Management:
  - `JourneyCubit` mit `JourneyLoading`, `JourneyLoaded`, `JourneyEmpty`, `JourneyError`.
  - `loadJourney()` laedt Proofs aus `ChainRepository` und sortiert reverse-chronologisch.
- Neue Journey-Ansicht:
  - `JourneyPage` mit `AppBar("My Journey")` und `BlocBuilder`.
  - Empty-State mit motivierendem Start-Hinweis.
  - Error-State mit Retry.
- Timeline-UI:
  - neues Widget `MeetingTimelineItem` mit vertikaler Kettenlinie, Node und Event-Card.
  - relative Zeitdarstellung via `timeago`.
  - technischer Beweis als kurze Proof-ID (`hash-prefix`) sichtbar.
  - staggered Entry-Animation pro Item (fade + slide).
- Navigation:
  - Map-Button im authentifizierten Bereich fuehrt jetzt zur `JourneyPage`.
- Tests erweitert:
  - neuer `journey_cubit_test.dart`.

### Milestone K: The Profile & Stats Engine

Status: `abgeschlossen (MVP)`

Umgesetzt:

- Statistik-Engine in der Domain:
  - `StatisticsService` mit:
    - `calculateTotalDistance(...)` via Haversine-Formel
    - `countUniquePeople(...)` (Public-Key-basiert, Owner ausgeschlossen)
    - `calculateStreak(...)` (aufeinanderfolgende Meeting-Tage)
    - `buildStats(...)` als aggregierter Einstiegspunkt.
- Gamification-Layer:
  - `badge_definitions.dart` mit Badge-Metadaten (`First Contact`, `Social Butterfly`, `Explorer`, `Marathon`).
  - `BadgeManager` mit Unlock-Logik und Fortschrittsberechnung pro Badge.
- Profil-State-Management:
  - neuer `ProfileCubit` mit `ProfileLoading`, `ProfileLoaded`, `ProfileError`.
  - laedt Identity + Proofs, berechnet Stats und Badges, liefert UI-fertigen Zustand.
- Profil-UI:
  - neue `ProfilePage` mit:
    - Header (Initials/Name)
    - Stats-Karten (Meetings, Distanz, People)
    - Streak-Anzeige
    - Badge-Grid mit unlocked/locked Visualisierung und Detail-Bottom-Sheet.
- Navigation:
  - Profilbild oben rechts im authentifizierten Bereich oeffnet jetzt `ProfilePage`.
- Tests erweitert:
  - `statistics_service_test.dart`
  - `badge_manager_test.dart`

### Implementierungsstand nach Modulen (Detail)

`lib/core/`:

- `lib/core/interfaces/crypto_provider.dart`: Interface fuer Random, Hash, Signatur, Verifikation ist vorhanden und stabil.
- `lib/core/crypto/ed25519_crypto_provider.dart`: konkrete Implementierung fuer Ed25519 + SHA-256 + Utility-Funktionen ist umgesetzt.
- `lib/core/identity.dart`: Key-Pair-Erzeugung und Signieren ueber gekapselten Private Key ist umgesetzt.
- `lib/core/di/service_locator.dart`: DI-Setup mit Lazy Singletons inkl. Camera Scanner Registrierung ist umgesetzt.
- `lib/core/utils/image_converter.dart`: Kameraformat-Konvertierung, Crop und Modell-Preprocessing ist umgesetzt.

`lib/data/`:

- `lib/data/datasources/tflite_biometric_scanner.dart`: Kamera-Frame + Face-Bounds -> echte MobileFaceNet Inferenz -> `FaceVector`.
- `lib/data/datasources/secure_key_value_store.dart`: Secure Storage Adapter fuer sensible Schluesseldaten.
- `lib/data/models/meeting_proof_model.dart`: Isar Datenmodell + Mapping zwischen DB und Domain.
- `lib/data/repositories/secure_identity_repository.dart`: sichere Persistenz/Restore von Identity Keys.
- `lib/data/repositories/isar_chain_repository.dart`: persistente Proof-Kette mit Integritaetsvalidierung beim Laden.

`lib/domain/entities/`:

- `lib/domain/entities/face_vector.dart`: Face-Vector Wrapper + Salted Hash vorhanden.
- `lib/domain/entities/location_point.dart`: Entitaet, Canonical String und JSON Roundtrip vorhanden.
- `lib/domain/entities/participant_signature.dart`: Entitaet, Canonical String und JSON Roundtrip vorhanden.
- `lib/domain/entities/meeting_proof.dart`: Payload/Proof Canonicalisierung, Hash-Bildung, Signaturpruefung und JSON Roundtrip vorhanden.

`lib/domain/services/`:

- `lib/domain/services/meeting_handshake_service.dart`: Erstellung eines signierten Proofs fuer zwei Teilnehmer umgesetzt.
- `lib/domain/services/chain_manager.dart`: Genesis-Regel + Link-Validierung + Proof-Validierung fuer die gesamte Kette umgesetzt.
- `lib/domain/services/face_matcher_service.dart`: Cosine Similarity und Match-Entscheidung umgesetzt.
- `lib/domain/services/statistics_service.dart`: Distanz-, Unique-People- und Streak-Berechnung fuer Gamification/Profile.

`lib/domain/gamification/`:

- `lib/domain/gamification/badge_definitions.dart`: Badge-Metadaten und Schwellenwerte.
- `lib/domain/gamification/badge_manager.dart`: Unlock- und Fortschrittslogik fuer Badges.

`lib/domain/interfaces/`:

- `lib/domain/interfaces/biometric_scanner.dart`: Scanner-Interface inkl. `BiometricScanRequest` und `FaceBounds` vorhanden.

`lib/domain/repositories/`:

- `lib/domain/repositories/identity_repository.dart`: Abstraktion fuer sichere Identity-Persistenz vorhanden.
- `lib/domain/repositories/chain_repository.dart`: Abstraktion fuer Proof-Chain Persistenz vorhanden.

`lib/domain/use_cases/`:

- `lib/domain/use_cases/create_meeting_proof_use_case.dart`: vorhanden.
- `lib/domain/use_cases/ensure_local_identity_use_case.dart`: Startup-Bootstrap der lokalen Identity vorhanden.
- `lib/domain/use_cases/verify_meeting_proof_use_case.dart`: vorhanden.
- `lib/domain/use_cases/validate_chain_use_case.dart`: vorhanden.

`test/`:

- `test/magellan_core_test.dart`: Phase-0 Kernlogik sowie Milestone-A-Tests vorhanden.
- `test/domain_use_cases_test.dart`: Milestone-B UseCase-Tests vorhanden.
- `test/face_matcher_service_test.dart`: Milestone-D Mathematik- und Schwellwerttests vorhanden.
- `test/image_converter_test.dart`: Preprocessing und Normalisierungslogik vorhanden.
- `test/secure_identity_repository_test.dart`: Speichern/Laden der Identity ueber Secure Storage Repository vorhanden.
- `test/isar_chain_repository_test.dart`: Isar Persistenz + Integritaetsfilterung bei Manipulation vorhanden.
- `test/service_locator_test.dart`: Milestone-C DI-Registrierung und Lazy-Singleton-Verhalten vorhanden.
- `test/widget_test.dart`: Flutter Test-Skeleton vorhanden.
- `test/statistics_service_test.dart`: Distanz-, Zero-Location- und Unique-People-Statistiktests.
- `test/badge_manager_test.dart`: Badge-Unlock-Logik fuer leeres Profil und Erst-Meeting.

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
- TFLite-Pipeline mit robustem Fehlerhandling (Model load/inference fallback) haerten.
- Optionale Liveness-Pruefung vor Embedding-Erzeugung integrieren.

`Phase 2 / Lokaler Handshake ueber zwei Geraete`:

- Session-Aufbau ueber QR definieren.
- Transportkanal fuer lokale Uebertragung integrieren.
- Bestaetigungs- und Fehlerzustaende (Timeout, Abbruch, Retry) modellieren.

`Phase 3 / Lokale Persistenz und Visualisierung`:

- Repository-Abfragen erweitern (Filter/Sort/Paging).
- Timeline/Graph Darstellung in der App aufbauen.
- Migration/Schema-Strategie fuer kuenftige Datenmodell-Aenderungen definieren.

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

- `abgeschlossen` Real TFLite Integration (Image Converter, MobileFaceNet Inference, Match-Flow im UI).

Milestone G:

- `abgeschlossen` Persistence & Secure Storage (Secure Identity + Isar Chain Repository + Integritaetschecks).

Milestone G-2:

- `abgeschlossen` Headless Logic Verification (Logger, mocked hardware edges, echter Roundtrip-Test).

Milestone G-3:

- `abgeschlossen` Multi-Face Logic (scanFaces, owner/guest resolver, Duo-Roundtrip-Test).

Milestone H:

- `abgeschlossen (erste Version)` Camera-first UX Layer (Magic Mirror) mit Auto-Auth und UI-Unlock.
- offen innerhalb H: Placeholder-Controls zu echten Capture-/Map-Features ausbauen.

Milestone I:

- `abgeschlossen (MVP)` Meeting Capture (Owner+Guest-Erkennung, Capture-Trigger, Proof-Speicherung, Success-Feedback).

Milestone J:

- `abgeschlossen (MVP)` Journey Timeline mit persistenter, visualisierter Begegnungskette.

Milestone K:

- `abgeschlossen (MVP)` Profile & Stats Engine (Statistiken, Badge-System, Profile-UI, Navigation).

---

Diese Datei ist der Masterplan. Operative Agenten-/Workflow-Regeln stehen in `AGENTS.md`.
