# AGENTS.md (Project-local)

Dieses Dokument steuert, wie wir im Projekt `malaqa` arbeiten.

Masterplan:

- Siehe `MALAQA.md` fuer Vision, Architektur, Roadmap und Status.

## 1. Prioritaeten

1. Korrektheit und Sicherheit vor Features.
2. Kleine, testbare Inkremente statt grosser Wuerfe.
3. Privacy-by-Design in jeder Schicht.

## 2. Arbeitsregeln fuer Implementierungen

- Bevorzugt TDD (erst Test, dann Code).
- Keine stillen Architekturwechsel ohne Doku-Update in `MALAQA.md`.
- Keine Persistenz von Rohbildern oder unsaltierten Face-Vektoren.
- Kryptografische Nutzdaten muessen kanonisch serialisiert und testbar sein.
- Oeffentliche APIs moeglichst stabil halten; Brechungen explizit dokumentieren.

## 3. Schichten und Verantwortlichkeiten

- `lib/core/`:
  - Kryptografie, Interfaces, technische Primitive.
- `lib/domain/entities/`:
  - Pure Datenobjekte mit klaren Invarianten.
- `lib/domain/services/`:
  - Protokolllogik und Validierungsregeln.
- `test/`:
  - Verhalten zuerst; Regressionen absichern.
- `bin/`:
  - reproduzierbare CLI-Simulationen fuer schnelle Verifikation.

## 4. Iterations-Prozess pro Task

1. Task-Scope in 1-3 Saetzen festhalten.
2. Fehlenden Test erstellen.
3. Minimal implementieren bis Test gruen.
4. Edge-Cases absichern.
5. Doku in `MALAQA.md` aktualisieren.
6. Commit mit engem Scope.

## 5. Commit-Konvention (empfohlen)

- `chore:` Setup, Tooling, Repo-Hygiene
- `feat(core):` neue Core-Funktionen
- `feat(domain):` neue Domain-Logik
- `test:` neue/angepasste Tests
- `docs:` Plan/Doku-Updates
- `refactor:` internes Redesign ohne Verhaltensaenderung

## 6. Definition of Ready (DoR)

Ein Task ist bereit, wenn klar ist:

- Was das erwartete Verhalten ist
- Welche Tests es nachweisen
- In welcher Schicht die Aenderung liegt

## 7. Definition of Done (DoD)

Ein Task ist fertig, wenn:

- Tests lokal gruen sind
- keine offensichtlichen Sicherheits-/Privacy-Regressions offen sind
- relevante Doku aktualisiert ist (`MALAQA.md`)

## 8. Startpunkt fuer die naechste Session

1. `MALAQA.md` lesen (Abschnitt "Vorschlag fuer konkrete naechste Milestones").
2. Einen Milestone waehlen.
3. Mit einem kleinen, testgetriebenen Teil starten.
