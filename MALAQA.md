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
- `lib/domain/entities/`: `FaceVector`, `MeetingProof`, `LocationPoint`, `ParticipantSignature`.
- `lib/domain/services/`: Handshake-Erzeugung und Chain-Validierung.
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

Offen:

- Face-Embedding-Stack fuer Mobile Start (ML Kit vs. InsightFace/TFLite).
- Persistenzwahl in Flutter-Phase (Isar vs. ObjectBox).
- P2P-Transport in Phase 2 (Nearby vs. libp2p basierter Ansatz).
- DID/Key-Rotation Strategie fuer Produktionsphase.

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

- API-Haertung fuer `MeetingProof` Serialisierung (JSON roundtrip + canonical encoding tests).

Milestone B:

- Domain-UseCases als explizite Klassen (CreateMeetingProof, VerifyMeetingProof, ValidateChain).

Milestone C:

- Flutter-App initialisieren und Core-Library als Abhaengigkeit einbinden.

---

Diese Datei ist der Masterplan. Operative Agenten-/Workflow-Regeln stehen in `AGENTS.md`.
