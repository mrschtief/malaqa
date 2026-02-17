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
- Standortintegration (Update 17. Februar 2026):
  - `MeetingCubit` versucht beim Capture die aktuelle Geraeteposition zu lesen.
  - gueltige Koordinaten werden in den `MeetingProof` geschrieben und sind damit sofort map-faehig.
  - bei fehlender Berechtigung/Service bleibt der Flow stabil (Fallback `0,0` + Log-Warnung).
- MVP-Limitation explizit:
  - Gast-Signatur wird lokal ueber einen Placeholder-Key simuliert,
    bis echter P2P-Handshake (beidseitige Signatur) in Phase 2 voll integriert ist.
- Tests erweitert:
  - neuer `meeting_cubit_test.dart` inkl. Happy Path (echte Coordinates) und Edge-Fall (Fallback `0,0`).

Offene Prioritaet (vor Blockchain):

- Echter kryptografischer P2P-Signaturtausch statt Placeholder-Guest-Key:
  1. Alice sendet kanonische Proof-Payload an Bob.
  2. Bob signiert auf seinem Geraet mit seinem echten Private Key.
  3. Bob sendet die Signatur an Alice zurueck.
  4. Persistenz erst nach gueltiger beidseitiger Signatur.
- Ziel:
  - mathematisch belastbarer Zustimmungsnachweis des Guests
  - keine "Self-asserted meetings" mehr.

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

### Milestone L: The World Map [x] Done

Status: `abgeschlossen (MVP)`

Umgesetzt:

- OpenStreetMap-Visualisierung mit `flutter_map` + `latlong2`.
- Neues Map-State-Management:
  - `MapCubit` mit `MapLoading`, `MapLoaded`, `MapEmpty`, `MapError`.
  - Filtert ungueltige Koordinaten (`0,0`) und erzeugt Marker + Chronologie-Polyline.
- Neue `MapPage`:
  - OSM TileLayer (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`)
  - Polyline fuer Kettenverlauf (Malaqa-Cyan, halbtransparent)
  - MarkerLayer mit Start-Flag + Standard-Marker
  - Marker-Tap zeigt Meeting-Details als Bottom Sheet.
- Optionaler aktueller Standort:
  - Runtime-Permission via `geolocator`
  - pulsierender Standortpunkt, falls Permission verfuegbar.
- Navigation:
  - Map-Button in `AuthPage` fuehrt auf die echte `MapPage`.
  - `JourneyPage` hat AppBar-Aktion `Show Map`.
- Tests erweitert:
  - `map_cubit_test.dart` (Marker/Polyline-Aufbau + Koordinaten-Filterung).

### Milestone M: The QR Fallback Bridge [x] Done

Status: `abgeschlossen (MVP)`

Umgesetzt:

- Neue zentrale Import-Logik in der Domain:
  - `ProofImporter` als wiederverwendbarer Inbound-Kanal fuer Proof-Transfers.
  - Input: JSON-Payload.
  - Ablauf:
    - Parse zu `MeetingProof`
    - Signatur-Validierung ueber `VerifyMeetingProofUseCase`
    - Duplikatpruefung ueber Proof-Hash
    - Persistenz via `ChainRepository`.
  - Output: `ImportResult` mit `success` / `duplicate` / `invalid`.
- QR-Sender (Fallback):
  - `QrShareDialog` zeigt QR fuer einen gespeicherten Proof.
  - Journey-Liste hat pro Meeting einen QR-Button.
- QR-Empfaenger:
  - neue `QrScanPage` mit `mobile_scanner`.
  - scannt QR, ruft `ProofImporter` auf, zeigt Ergebnisstatus (success/duplicate/invalid).
- App-Integration:
  - In `AuthPage` steht im authentifizierten Zustand ein unauffaelliger `Scan QR` Einstieg bereit (oben links).
- Architekturziel fuer naechste Phase:
  - dieselbe `ProofImporter`-Logik kann in Milestone N fuer BLE/WiFi-Direct Receptions genutzt werden.
- Tests erweitert:
  - `proof_importer_test.dart` (valid import, duplicate detection, invalid payload).

### Milestone N: The Proximity Mesh & Auto-Discovery [x] Done

Status: `abgeschlossen (MVP)`

Umgesetzt:

- P2P-Infrastruktur:
  - `NearbyService` Abstraktion + `NearbyConnectionsService` Implementierung auf Basis `nearby_connections`.
  - Sender-Fluss: Advertising startet mit serialisiertem Payload.
  - Empfaenger-Fluss: Discovery + Auto-RequestConnection + Auto-AcceptConnection.
  - Payload-Weitergabe als JSON-Bytes ueber Nearby.
- Proximity-Orchestrierung:
  - neuer `ProximityCubit` mit Rollenlogik fuer Sender/Empfaenger.
  - bei `AuthAuthenticated`: Discovery aktiv.
  - bei `MeetingSuccess`: Advertising fuer 30 Sekunden, danach Rueckkehr zu Discovery.
  - eingehender Payload:
    - Parse Envelope (`proof` + `guestVector`)
    - Face-Match gegen lokalen Owner-Vector
    - nur bei Match -> `ProximityMatchFound`.
- In-App Notification Overlay:
  - neues Widget `ProximityNotificationOverlay` ueber der Kamera.
  - Card-Flow:
    - "Jemand hat dich gerade gesehen"
    - Aktionen: `Claim & Save` / `Ignorieren`
    - Claim nutzt zentralen `ProofImporter`.
- Integration in bestehende Flows:
  - `AuthPage`: Auth-State toggelt Discovery.
  - `AuthPage`: Meeting-Success triggert Advertising mit transferierbarer Payload.
  - `MeetingSuccess` transportiert jetzt den erkannten Guest-Vector fuer den Sender-Transferkontext.
- Plattformberechtigungen:
  - Android: Bluetooth + Nearby-WiFi + Location Permissions erweitert.
  - iOS: Bluetooth/LocalNetwork/Bonjour Usage Keys ergaenzt.
- Tests erweitert:
  - `proximity_cubit_test.dart` prueft Match-/No-Match-Verhalten mit gemocktem Nearby-Kanal.

### Milestone O: The Truth Test (Liveness & Anti-Spoofing) [x] Done

Status: `abgeschlossen (MVP)`

Umgesetzt:

- Liveness-Domainkomponente:
  - `LivenessGuard` in `lib/domain/security/liveness_guard.dart`.
  - zufaellige Challenge pro Session (`smile` oder `blink`).
  - Challenge-Auswertung auf Basis von Face-Klassifikationswerten.
- Scanner-Metadaten erweitert:
  - `FaceBounds` transportiert jetzt optional:
    - `smilingProbability`
    - `leftEyeOpenProbability`
    - `rightEyeOpenProbability`
- ML Kit Pipeline erweitert:
  - `FaceDetectorOptions(enableClassification: true)` in der Camera-Schleife aktiviert.
  - Face-Attribute werden in den Scan-Flow uebergeben.
- Auth-Flow gehaertet:
  - `AuthCubit` verlangt zusaetzlich zur Face-Similarity einen bestandenen Liveness-Check.
  - UI zeigt proaktiv Challenge-Hinweise (z. B. "Kurz laecheln!" / "Kurz blinzeln!").
- Meeting-Flow gehaertet:
  - `MeetingCubit` validiert Liveness des Guests vor Capture-Freigabe.
  - Capture-Button wird erst aktiv, wenn Guest-Liveness erfolgreich ist.
  - Gast-Reticle + Badge visualisieren Verifikationsfortschritt.
- Tests erweitert:
  - `liveness_guard_test.dart` mit Stream-aehnlicher Sequenz (neutral -> neutral -> smile).
  - bestehende Auth-/Meeting-Tests auf Liveness-Metadaten angepasst.

### Milestone P: The IPFS Bridge (Option B) [x] Done

Status: `abgeschlossen (Local Mock + vorbereiteter HTTP-Pfad)`

Umgesetzt:

- Neue Dependencies:
  - `http`
  - `cid`
- Domain-Erweiterung:
  - neues Repository-Interface `IpfsRepository`.
  - `MeetingProof` um optionales Feld `ipfsCid` erweitert (nicht Teil der signierten Canonical-Payloads).
- Data-Erweiterung:
  - `HttpIpfsRepository` mit:
    - lokaler CID-Berechnung aus `canonicalJson()`
    - Simulationsmodus (Option B, ohne API-Key)
    - optionalem HTTP-Uploadpfad fuer spaeteren Realbetrieb
    - klaren Fehlern bei Timeout/Client/Response-Format.
- Sync-Orchestrierung:
  - neuer `DecentralizedSyncService`:
    - laedt lokale Proofs
    - synchronisiert nur unsynced Eintraege (`ipfsCid == null`)
    - persistiert die erhaltene CID in Isar.
- Persistenz:
  - Isar-Model `MeetingProofModel` um `ipfsCid` erweitert.
  - Codegen aktualisiert (`meeting_proof_model.g.dart`).
- DI/Wiring:
  - `IpfsRepository` und `DecentralizedSyncService` im Service Locator registriert.
- Tests erweitert:
  - `test/ipfs_repository_test.dart`
  - `test/decentralized_sync_service_test.dart`

Offene Prioritaet (vor Blockchain):

- Wechsel von `simulate` auf echten IPFS-Betrieb:
  - Anbindung an echten Pinning-/Node-Pfad (z. B. Pinata oder Helia).
  - Upload verschluesselter Proof-Artefakte.
  - persistente Nutzung echter CIDs fuer spaeteres Restore auf neuem Geraet.

### Milestone Q: The Blockchain Anchor [x] Done

Status: `abgeschlossen (offline-signing MVP, no-gas mode)`

Umgesetzt:

- Neue Dependencies:
  - `web3dart`
  - `bip39`
- Domain-Erweiterung:
  - neues Repository-Interface `AnchorRepository` mit `anchorProof(String proofHash)`.
- Wallet-Layer:
  - `CryptoWalletService` leitet deterministisch aus der vorhandenen App-Identity (Ed25519-Secret) ein Ethereum-kompatibles Secp256k1-Keymaterial ab.
  - Ableitung nutzt BIP39 (`entropy -> mnemonic -> seed`) und validiert den resultierenden Private Key gegen den Secp256k1-Range.
- Ethereum-Anchor-Repository:
  - `EthereumAnchorRepository` baut Anchor-Transaktionen, kodiert `proofHash` als `storeHash(bytes32)`-CallData und signiert offline.
  - Simulation-Modus erzeugt lokal gueltigen TX-Hash ohne Netzwerkkosten.
  - optionaler Sender-Hook erlaubt spaeteres echtes Broadcasting oder Test-Mocking.
- DI/Wiring:
  - `CryptoWalletService` und `AnchorRepository` im Service Locator registriert (standardmaessig `simulateOnly: true`).
- Tests erweitert:
  - `test/ethereum_anchor_test.dart` prueft:
    - deterministische Wallet-Ableitung
    - korrekte Hash-Kodierung in Transaction-Data
    - kryptografisch gueltige Signatur
    - Sender-Mocking und Simulationspfad.

### Milestone R: The Grand Entrance (Onboarding & Settings) [x] Done

Status: `abgeschlossen (MVP)`

Umgesetzt:

- First-Run Gate:
  - neues `AppSettingsService` (SharedPreferences-basiert) fuer `isFirstRun` und `nearbyVisibility`.
  - `MalaqaApp` startet jetzt ueber einen Root-Gate:
    - Erststart -> `OnboardingPage`
    - danach -> `AuthPage`.
- Onboarding:
  - neue `OnboardingPage` mit 3 Slides (Identity, Chain, Permissions) und `Initiiere Protokoll`-CTA.
  - sequentielle Permission-Abfrage fuer Kamera, Standort und Nearby/Bluetooth.
  - Abschluss wird im Settings-Service persistiert und geloggt.
- Settings Vault:
  - neue `SettingsPage` mit Bereichen:
    - Account: `Backup Identity` (Recovery Phrase anzeigen, mit Warnhinweis).
    - Privacy: `Nearby Visibility` Toggle.
    - System: `Reset App` (Danger Zone).
    - About: Versionstext.
  - `ProfilePage` hat jetzt ein Gear-Icon als Einstieg in Settings.
- Nearby Visibility Wiring:
  - `AuthPage` respektiert den Toggle:
    - Discovery/Advertising nur wenn `nearbyVisibility = true`.
    - bei deaktiviertem Toggle werden Proximity-Flows sauber gestoppt.
- Reset Flow:
  - loescht lokale Isar-Proofs und SecureStorage-Keys.
  - setzt App-Settings auf Erststart zurueck.
  - fuehrt den User wieder in den First-Run-Zustand.
- Testabdeckung:
  - neues `test/app_settings_service_test.dart` fuer First-Run/Toggle/Reset-Persistenz.

Offene Prioritaet (vor Blockchain):

- Identity-Restore-Flow vervollstaendigen:
  - "I have an account"-Pfad im Onboarding.
  - Eingabe/Validierung der Recovery Phrase.
  - deterministische Re-Ableitung derselben Identity auf neuem Geraet.
  - optional: automatisches Nachladen vorhandener Proofs ueber CID/IPFS.

### Implementierungsstand nach Modulen (Detail)

`lib/core/`:

- `lib/core/interfaces/crypto_provider.dart`: Interface fuer Random, Hash, Signatur, Verifikation ist vorhanden und stabil.
- `lib/core/crypto/ed25519_crypto_provider.dart`: konkrete Implementierung fuer Ed25519 + SHA-256 + Utility-Funktionen ist umgesetzt.
- `lib/core/identity.dart`: Key-Pair-Erzeugung und Signieren ueber gekapselten Private Key ist umgesetzt.
- `lib/core/di/service_locator.dart`: DI-Setup mit Lazy Singletons inkl. Camera Scanner Registrierung ist umgesetzt.
- `lib/core/utils/image_converter.dart`: Kameraformat-Konvertierung, Crop und Modell-Preprocessing ist umgesetzt.
- `lib/core/services/app_settings_service.dart`: persistiert First-Run und Nearby-Sichtbarkeit fuer Onboarding/Settings.

`lib/data/`:

- `lib/data/datasources/tflite_biometric_scanner.dart`: Kamera-Frame + Face-Bounds -> echte MobileFaceNet Inferenz -> `FaceVector`.
- `lib/data/datasources/nearby_service.dart`: P2P Discovery/Advertising/Payload-Transport als gekapselter Nearby-Adapter.
- `lib/data/datasources/device_location_provider.dart`: liest aktuelle Geraeteposition fuer Meeting-Capture.
- `lib/data/datasources/secure_key_value_store.dart`: Secure Storage Adapter fuer sensible Schluesseldaten.
- `lib/data/models/meeting_proof_model.dart`: Isar Datenmodell + Mapping zwischen DB und Domain.
- `lib/data/repositories/secure_identity_repository.dart`: sichere Persistenz/Restore von Identity Keys.
- `lib/data/repositories/isar_chain_repository.dart`: persistente Proof-Kette mit Integritaetsvalidierung beim Laden.
- `lib/data/repositories/ethereum_anchor_repository.dart`: Ethereum/Polygon Anchor-Layer mit offline signierten Transaktionen.

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
- `lib/domain/services/decentralized_sync_service.dart`: synchronisiert unsynced lokale Proofs Richtung IPFS und schreibt `ipfsCid` zurueck.
- `lib/domain/services/crypto_wallet_service.dart`: deterministic Key-Derivation fuer Ethereum-Credentials aus lokaler Identity.

`lib/domain/gamification/`:

- `lib/domain/gamification/badge_definitions.dart`: Badge-Metadaten und Schwellenwerte.
- `lib/domain/gamification/badge_manager.dart`: Unlock- und Fortschrittslogik fuer Badges.

`lib/domain/security/`:

- `lib/domain/security/liveness_guard.dart`: Challenge-basierte Anti-Spoofing-Liveness-Logik.

`lib/domain/interfaces/`:

- `lib/domain/interfaces/biometric_scanner.dart`: Scanner-Interface inkl. `BiometricScanRequest` und `FaceBounds` vorhanden.
- `lib/domain/interfaces/location_provider.dart`: Abstraktion fuer aktuelle Geraeteposition (testbarer Geo-Zugriff).

`lib/domain/repositories/`:

- `lib/domain/repositories/identity_repository.dart`: Abstraktion fuer sichere Identity-Persistenz vorhanden.
- `lib/domain/repositories/chain_repository.dart`: Abstraktion fuer Proof-Chain Persistenz vorhanden.
- `lib/domain/repositories/ipfs_repository.dart`: Abstraktion fuer dezentrale Proof-Uploads (CID-basierter Storage) vorhanden.
- `lib/domain/repositories/anchor_repository.dart`: Abstraktion fuer Blockchain-Anchor-Operationen vorhanden.

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
- `test/map_cubit_test.dart`: Geo-Transformationslogik fuer Marker/Polyline und Invalid-Filtering.
- `test/proof_importer_test.dart`: QR-Importkern mit Validierung und Duplikat-Erkennung.
- `test/proximity_cubit_test.dart`: Auto-Discovery Logik (Payload-Match vs. stille Verwerfung).
- `test/liveness_guard_test.dart`: Liveness-Challenge Sequenztest fuer Anti-Spoofing.
- `test/ipfs_repository_test.dart`: canonical JSON + CID-Berechnung + Timeout-Fehlerpfad fuer IPFS-Bridge.
- `test/decentralized_sync_service_test.dart`: Sync-Flow fuer unsynced Proofs inkl. Erfolgs-/Fehlerpfad.
- `test/ethereum_anchor_test.dart`: Wallet-Derivation, offline-signing und Anchor-TX-Data-Verifikation.
- `test/app_settings_service_test.dart`: Persistenztests fuer Onboarding- und Settings-Flags.

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
- Liveness-Checks feintunen (z. B. mehrstufige Challenges, Zeitfenster, Fehlertoleranz).

`Phase 2 / Lokaler Handshake ueber zwei Geraete`:

- Session-Aufbau ueber QR definieren.
- Transportkanal fuer lokale Uebertragung integrieren.
- Bestaetigungs- und Fehlerzustaende (Timeout, Abbruch, Retry) modellieren.

`Phase 3 / Lokale Persistenz und Visualisierung`:

- Repository-Abfragen erweitern (Filter/Sort/Paging).
- Timeline/Graph Darstellung in der App aufbauen.
- Migration/Schema-Strategie fuer kuenftige Datenmodell-Aenderungen definieren.

`Security-Haertung`:

- Spoofing-Schutz auf "Photo + Replay + Screen Re-Capture" erweitern (z. B. Moire-Checks).
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

Milestone L:

- [x] Done - World Map (OSM), Pfad-Visualisierung und Karten-Navigation.

Milestone M:

- [x] Done - QR Fallback Bridge fuer Proof-Transfer inkl. zentralem ProofImporter.

Milestone N:

- [x] Done - Proximity Mesh mit Nearby Auto-Discovery und In-App Claim-Overlay.

Milestone O:

- [x] Done - Liveness & Anti-Spoofing fuer Auth- und Meeting-Flow.

Milestone P:

- [x] Done - IPFS-Bridge inkl. CID-Berechnung, `ipfsCid`-Persistenz und vorbereiteter HTTP-Upload-Architektur.

Milestone Q:

- [x] Done - Blockchain-Anchor-Layer mit Ethereum-kompatibler Wallet-Ableitung und vorbereiteter TX-Broadcast-Schnittstelle.

Milestone R:

- [x] Done - First-Run-Onboarding, Settings-Vault und kontrollierbarer Nearby-Visibility-/Reset-Flow.

Milestone R-UX:

- [x] Done (17. Februar 2026) - UX-Polish:
  - Liveness auf "Smile ODER Blink" gelockert (Thresholds: Smile > 0.6, Left Eye < 0.2).
  - Auth-Hinweis auf "Bitte laecheln ODER kurz blinzeln" vereinheitlicht.
  - Nearby Permission-Fail auf Soft-Fail umgestellt (`ProximityPermissionError`) statt harter Fehler.
  - Dezente Warnkarte mit `Icons.bluetooth_disabled` + `Aktivieren` (`openAppSettings`) im Overlay.
  - Kameraformat in Auth auf Android explizit `ImageFormatGroup.yuv420` gesichert (mit Warnkommentar).

Milestone R-Geo:

- [x] Done (17. Februar 2026) - Meeting-Location Capture + Map-Roundtrip:
  - neue `LocationProvider`-Abstraktion + `DeviceLocationProvider` (Geolocator).
  - `MeetingCubit` speichert beim Capture aktuelle Koordinaten statt fixem `0,0`.
  - Soft-Fallback auf `0,0`, wenn Location nicht verfuegbar ist.
  - Map bleibt robust und zeigt weiterhin nur valide Koordinaten.

Milestone R-Next (geplant, vor Blockchain):

- [ ] Echter P2P-Signaturtausch fuer MeetingProof (beidseitige Zustimmung kryptografisch beweisbar).
- [ ] IPFS Real Mode inkl. echtem Uploadpfad und persistenten CIDs.
- [ ] Identity Restore Flow im Onboarding ("I have an account" + Phrase-Recovery).
- [ ] iOS-Validierung auf Realgeraeten inkl. Nearby-Interop Android <-> iOS.

## 9. Entwicklungsplan: Blockchain Integration (Stand 17. Februar 2026)

### 9.1 Aktueller Realitaetscheck

Kann die App auf zwei Handys gespielt werden und per Blockchain claimen?

- Ja fuer lokalen Meeting-Flow:
  - APK auf zwei Android-Geraeten ist moeglich.
  - P2P-Handshake (Nearby oder QR) funktioniert.
  - `MeetingProof` wird kryptografisch signiert und lokal (Isar) persistiert.
  - Begegnungen sind in Journey und Map sichtbar.
- Nein fuer echtes On-Chain-Claiming:
  - `EthereumAnchorRepository` laeuft derzeit standardmaessig mit `simulateOnly: true`.
  - Signing/Transaction-Building sind echt, Broadcast auf ein reales Netzwerk ist noch nicht aktiviert.
  - Es fehlt aktuell:
    - deployed Smart Contract (`storeHash`) auf Testnet/Mainnet
    - echte RPC-Integration (z. B. Infura/Alchemy)

### 9.2 Roadmap 2026+: Von Simulation zu Web of Trust

Phase 1 "The Real Network" (Q2 2026):

- Milestone S (geplant): Smart Contract Deployment
  - Minimaler `ProofRegistry`-Contract auf guenstigem L2-Testnetz (z. B. Polygon Amoy oder Base Sepolia).
  - Kernfunktion: Mapping `proofHash -> blockTimestamp + participants`.
- Milestone T (geplant): Live Anchoring
  - `EthereumAnchorRepository` von `simulate` auf echten Broadcast umstellen.
  - Optional Relayer oder Account Abstraction integrieren, damit User kein eigenes Gas-Handling brauchen.
- Milestone U (geplant): Real IPFS Pinning
  - Echte Pinning-Integration (z. B. Pinata oder eigener Helia/Node-Pfad) fuer dezentral abrufbare Metadaten.

Phase 2 "The Web of Trust" (Q3 2026):

- Milestone V (geplant): Graph Visualization
  - Netzwerkansicht statt nur Timeline/Kette.
  - Hop-Distanz/Verbindungsgrad zwischen Identities visualisieren.
- Milestone W (geplant): Trust Score / Vouching
  - Bewertungslogik fuer Vertrauensniveau.
  - Basisfaktoren: Identity-Alter, Vielfalt der Meetings, Anchoring-Status.

Phase 3 "Hardened Privacy & Recovery" (Q4 2026):

- Milestone X (geplant): Social Recovery
  - Wiederherstellung von Identity/Keymaterial ueber definierten Guardian-Kreis.
- Milestone Y (geplant): Zero-Knowledge Proofs
  - Langfristige ZKP-basierte Nachweise (z. B. Eigenschaften ohne Offenlegung biometrischer Rohdaten).

Phase 4 "Ecosystem" (ab 2027):

- Milestone Z (geplant): Malaqa SDK
  - Integrationsfaehiges SDK fuer Drittprodukte (z. B. Events, Communities, Marktplaetze).

### 9.3 Vorrangige Schritte vor Blockchain (kritische Luecken)

1. Echter P2P-Signaturtausch (Milestone I Update)
   - Beidseitige Signaturen ueber Nearby/QR austauschen, erst danach speichern.
2. IPFS Real Mode (Milestone P Update)
   - von lokalem Mock auf echten Upload + echte CIDs umstellen.
3. Identity Restore (Milestone R Update)
   - Onboarding-Flow fuer Recovery Phrase und Rehydration der Identity.
4. iOS Validierung
   - Realgeraete-Testmatrix fuer Permissions, Kamera, Nearby-Interoperabilitaet (iOS <-> Android).

### 9.4 Danach: Live Blockchain Anchoring

Erst nach Schliessung der Punkte aus 9.3 werden Smart-Contract-Deployment und Live-Broadcast (Milestones S und T) als Hauptfokus umgesetzt.
---

Diese Datei ist der Masterplan. Operative Agenten-/Workflow-Regeln stehen in `AGENTS.md`.
