# RagFit | Plan — Documentation Map

> **Einstieg für KI-Agenten:** Lies zuerst [`../erynoa.md`](../erynoa.md) (Agent Planner), danach diese Dokumentationskarte und [`./ARCHITECTURE.md`](./ARCHITECTURE.md).  
> **Einstieg für Entwickler & Operatoren:** Starte mit [`../README.md`](../README.md) und [`./ARCHITECTURE.md`](./ARCHITECTURE.md).

---

## 1. Lesepfad für KI-Agenten (Progressive Disclosure)

1. **[`../erynoa.md`](../erynoa.md)** — Kanonische Projektdoktrin, Invarianten (`I-1`..`I-5`), Verbote (`F-1`..`F-4`), Tooling (`nix develop`, `just doctor`, `just image`, `just ci-quick`).
2. **[`./ARCHITECTURE.md`](./ARCHITECTURE.md)** — Rolle von `RagFit | Plan` in der **RagFit v4.0 7-Schichten-Gesamtarchitektur (`L0`–`L6`)**, **GPLv3-Lizenzisolation** über `ragfit-plan-bridge`, OIDC-Team-Gates und Systemgrenzen.
3. **[`./work/ROADMAP.md`](./work/ROADMAP.md)** — Abgeschlossene Meilensteine und kommende Arbeitspakete unter `docs/work/`.
4. **[`../CHANGES-RAGFIT.md`](../CHANGES-RAGFIT.md)** — Verbindliches GPLv3-Änderungsprotokoll aller RagFit-Anpassungen und Patches gegenüber OpenProject `v17.9.1`.

---

## 2. Verzeichnisstruktur unter `docs/`

| Pfad | Inhalt & Zweck | Zielgruppe |
|---|---|---|
| [`docs/README.md`](./README.md) | Dieser Dokumentations-Index und Navigationspfad | Agenten & Menschen |
| [`docs/ARCHITECTURE.md`](./ARCHITECTURE.md) | Normative Architektur von `RagFit \| Plan` im 7-Schichten-Modell (`L0`–`L6`, v4.0) & GPLv3-Isolation | Architekten, Agenten, Reviewer |
| [`docs/work/ROADMAP.md`](./work/ROADMAP.md) | Roadmap, Patch-Serie `0001`..`0005`, `ragfit-plan-bridge` und Nix-OCI-Status | Produkt, Agenten |
| `docs/work/specs/` | Technische Spezifikationen (`SPEC-*`) nach Skill `erynoa-docs` | Agenten & Entwickler |
| `docs/work/plans/` | Umsetzungspläne (`PLAN-*`) für mehrstufige Änderungen | Agenten & Entwickler |
| `docs/work/notes/` | Technische Notizen, Analysen und Entscheidungsprotokolle (`NOTE-*`) | Agenten & Entwickler |
| [`../README-RAGFIT-CI.md`](../README-RAGFIT-CI.md) | CI-Trigger-Steuerung (`#RAGFIT-OFF#`), Leak-Guard, SLSA-Provenance und Release-Ablauf | Release-Engineering & SecOps |
| `docs/api/` | OpenProject REST API v3 Spezifikation und Endpunkt-Dokumentation | Integratoren |
| `docs/development/` | Backend-/Frontend-Entwicklungsrichtlinien der Upstream-Codebasis | Entwickler |
