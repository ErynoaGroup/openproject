# erynoa.md — project agent doctrine

<!-- AGENT-PLANNER:BEGIN -->
## Agent planner (self-orchestration)

> **Read this first.** Humans: [README.md](./README.md) · Architecture: [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).  
> **Law R2 · DynHom:** maximal homogen (gleiche Homes/Verträge) · maximal dynamisch (Signal-Tiefe). `rule-01-dynamic-homogeneous.md`

| | |
|--|--|
| **Mission** | RagFit \| Plan (Schicht L3 Operative Domain Core): System of Record für Projects, WorkPackages, Sprints, Boards, Roadmaps und TimeEntries; GPLv3-isoliert über das externe stateless Sidecar `ragfit-plan-bridge` auf Stream `RAGFIT_PLAN` |
| **Session goal** | Aus Auftrag, sonst: orientieren + `just doctor` + `just ci-quick` |
| **Success** | `just doctor` grün · `just ci-quick` grün · `nix build .#container` (`just image`) grün · `erynoa-gate` & `audit-erynoa` grün |
| **DX** | `nix develop` · `just` · `just doctor` · `just image` · `just ci-quick` |
| **Work-root** | `docs/work/` (`ROADMAP.md`, `specs/`, `plans/`, `notes/`) |
| **Branching** | trunk-based · Pull Requests (PR) → `main` |
| **Erynoa First** | Remote **must** be `https://github.com/ErynoaGroup/ragfit-plan.git` — never personal org |
| **Paths** | `$AGENT_SURFACE_ROOT` / `$REPO_INDEX_ROOT` / git — never `/Users/…` in doctrine |
| **Repo-index** | MUST register in `https://github.com/ErynoaGroup/.repo-index.git` · skill `repo-index` |

**Read order:** (1) this planner (2) `justfile` (3) [README.md](./README.md) (4) [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) (5) [docs/README.md](./docs/README.md)

**Do first:** root/branch → `nix develop` → `just doctor` → classify task → execute → verify

**Orchestration**

| Task | Route |
|------|--------|
| Orient | M0 · planner + `just doctor` |
| Doctrine missing/thin | `erynoa-md` M1–M2 |
| Docs / SPEC·PLAN | `erynoa-docs` |
| Quality | `erynoa-md` M3 |
| Feature / product change (Erynoa org repo) | **`erynoa-project` primary · `pipeline=vp-<id>`** (R9) → `docs/work/` PLAN + branch + implement; Ultracode only as runtime |
| Ship gate | M5 |
| Wide explore / N independent reads | **subagents** (read-only) → parent merge |

**Subagents:** solo default; independent ready work only within actual free child slots and compatible file ownership. Full child brief + distilled return; parent merge + verify.

**Efficiency:** plan→act→verify · progressive disclosure · tools > guessing · compact context.

**Voice:** *Craft Edge* — sharp, path-backed, short; no AI-slop (`voice.md`).

**DynHom:** gleiche Form überall; Tiefe/Packs/Fan-out nur signal-gebunden.

**Do not:** skip planner · unregistered non-playground work · local structure dialect · blind checklists · subagent spam · credentials in git · brew/apt as SSOT · doctrine dump
<!-- AGENT-PLANNER:END -->

---

## Identity

| Field | Value |
|-------|--------|
| **Project** | RagFit \| Plan (`ErynoaGroup/ragfit-plan`, öffentlich unter GPLv3) |
| **Line / Layer** | Plattform-Dienstfamilie `RagFit \| *` · Schicht L3 (Operative Domain Core — Project & Work Management SoR · GPLv3) |
| **Purpose** | System of Record für Projects, WorkPackages, Sprints, Boards, Roadmaps und TimeEntries; OIDC-gebunden an `RagFit \| Source` / `RagFit \| Auth` und asynchron entkoppelt über `ragfit-plan-bridge` auf Stream `RAGFIT_PLAN` |
| **Upstream** | OpenProject `v17.9.1` (`GPL-3.0-only`), Änderungen und Patch-Serie dokumentiert in [CHANGES-RAGFIT.md](./CHANGES-RAGFIT.md) und `ragfit/patches/` |
| **Owners** | Niklas Klein |
| **Status / tier** | Production Core · Tier 1 · Release-Konvention `ragfit-plan-v<semver>` |
| **Stack** | Ruby 3.4 / Rails 8, Angular / TypeScript (`npm` workspace), PostgreSQL, Nix Flake (`buildLayeredImage`), Just, GitHub Actions CI workflows |
| **Default branch** | `main` |
| **Visibility** | public (GPLv3 corresponding source) |
| **License** | `GPL-3.0-only` ([LICENSE](./LICENSE), [COPYRIGHT](./COPYRIGHT), [CHANGES-RAGFIT.md](./CHANGES-RAGFIT.md)) |
| **last_reviewed** | 2026-10-15 |

## Invariants

1. **I-1** — **Single System of Record (Schicht `L3`):** `RagFit | Plan` besitzt exklusiv Projects, WorkPackages, Sprints, Relations, TimeEntries und Projekt-Boards. Kein anderer Dienst greift direkt auf die PostgreSQL-Datenbank von `RagFit | Plan` zu.
2. **I-2** — **Strikte GPLv3-Lizenzisolation (Kein SDK-In-Process-Linking):** In den unter GPLv3 stehenden Ruby-/Rails-Kern wird niemals proprietärer Rust-, TypeScript- oder Python-Code aus `ragfit-sdk` gelinkt. Die Kopplung zu `RagFit | Bus` (NATS JetStream Stream `RAGFIT_PLAN`) erfolgt ausschließlich über Standard-HTTP/REST v3 und das externe, prozessual getrennte, stateless Sidecar `ragfit-plan-bridge`.
3. **I-3** — **Fail-Closed OIDC Team-Autorisierung (`ragfit/patches/0001..0003`):** Anmeldung und Admin-Rechte erfolgen über OpenID Connect mit vollständigen `<org>:<team>`-Claims (z. B. `ErynoaGroup:plan-user`, `ErynoaGroup:platform-admin`). Reine Organisationsnamen ohne `:team` berechtigen niemals; OIDC-verknüpfte Konten können sich nicht per Passwort anmelden.
4. **I-4** — **Patch-Serien- & Notice-Konsistenz (`just patches` & `just notice-guard`):** Jede Änderung an Upstream-Code liegt als umkehrbar anwendbarer Patch unter `ragfit/patches/*.patch` vor und ist gemäß GPLv3 §5(a) mit Datum in `CHANGES-RAGFIT.md` dokumentiert. `LICENSE`, `COPYRIGHT` und `COPYRIGHT_short` bleiben unverändert.
5. **I-5** — **Public-Repo Leak-Guard (`ragfit/ci/leak-guard.sh`):** Keine Klammeraffen-Erwähnungen in Prosa/Kommentaren (außer `@sha256:`-Digests), keine privaten IP-Adressen, keine internen Hostnamen und keine Infrastruktur-Domänen.

## Forbidden

1. **F-1** — Commit von Zugangsdaten, privaten Schlüsseln, Tokens, internen Hostnamen, privaten IP-Adressen oder Klammeraffen-Handles (`ragfit/ci/leak-guard.sh` bricht hart ab).
2. **F-2** — Home-Skill-Verzeichnisse als SSOT behandeln (nutze ausschließlich `$AGENT_SURFACE_ROOT`) oder absolute lokale Benutzerpfade in Dokumentationen hinterlegen.
3. **F-3** — Einbinden oder Linken proprietärer Bibliotheken (`ragfit-sdk`) direkt in den GPLv3-Ruby-Prozess oder Verändern der Upstream-Lizenzdateien (`LICENSE`, `COPYRIGHT`, `COPYRIGHT_short`).
4. **F-4** — Aktivieren automatischer Upstream-GitHub-Actions-Trigger ohne `#RAGFIT-OFF# `-Präfix (`ragfit/ci/trigger-check.sh`) oder Ausführen von `git push` ohne explizite Freigabe.

## How agents work

1. **Agent planner zuerst lesen** → Session-Ziel klären → `nix develop` und `just doctor` ausführen.
2. **Architektur- & Patch-Kontext prüfen:** Bei Änderungen an OIDC, Header oder Build-Pipelines zuerst [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md), [CHANGES-RAGFIT.md](./CHANGES-RAGFIT.md) und `ragfit/patches/` lesen.
3. **Trunk-based Workflow:** Kurze Feature-Branches und Pull Requests (PR) gegen `main`, Conventional Commits verwenden, niemals `git push` ohne expliziten Auftrag.
4. **Verifikation vor Abschluss:** Vor jedem Abschluss müssen `just doctor`, `just ci-quick` und `nix flake show` fehlerfrei durchlaufen.

## Architecture map

> Detailmodell der 7-Schichten-Gesamtarchitektur (`L0`–`L6`) (v4.0) und der GPLv3-Lizenzisolation: siehe [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                  RagFit | Plan (Schicht L3 Operative Domain Core · GPLv3)               │
│                                                                              │
│  ┌──────────────────────────┐  ┌──────────────────────────┐                  │
│  │  Rails 8 / Puma (:8080)  │  │  RagFit Patch-Serie      │                  │
│  │  Web-UI + API v3 (HAL)   │  │  0001 sso-unlock         │                  │
│  │  Projects, WorkPackages, │  │  0002 oidc-admin-group   │                  │
│  │  Sprints, TimeEntries    │  │  0003 oidc-login-gate    │                  │
│  │  Outbound Webhooks       │  │  0004 e2e-user-cleanup   │                  │
│  │                          │  │  0005 erynoa-header 1.1.1│                  │
│  └────────────┬─────────────┘  └─────────────┬────────────┘                  │
└───────────────┼──────────────────────────────┼───────────────────────────────┘
                │                              │
   Sync (REST API v3 / OIDC)       Standard-HTTP Webhook (Netzwerkgrenze)
                ▼                              ▼
┌───────────────────────────────┐  ┌───────────────────────────────────────────┐
│ L1 RagFit | Auth & L3 Source  │  │ ragfit-plan-bridge (Stateless Sidecar)    │
│ L2 RagFit | SDK (REST Client) │  │ Validiert HMAC → übersetzt in signiertes  │
│ L4 RagFit | Ops (Orchestrator)│  │ RagFitEventEnvelopeV1 auf RAGFIT_PLAN:    │
└───────────────────────────────┘  │ - plan.work_package.created/updated.v1    │
                                   │ - plan.sprint.*.v1                        │
                                   └───────────────────────────────────────────┘
```

| Module / Path | Responsibility | May depend on |
|---------------|----------------|---------------|
| `ragfit/patches/` | Kanonische Patch-Serie (`0001`..`0005`) gegen Upstream OpenProject | Upstream Rails/OpenProject |
| `ragfit/ci/` | Sicherheits- und Compliance-Guards (`leak-guard.sh`, `notice-guard.sh`, `asset-guard.sh`, `trigger-check.sh`) | Bash, Perl, Git |
| `ragfit/brand/` | Unveränderte RagFit-Marken-Assets, verifiziert gegen `PROVENANCE.md` | Statische PNG-Assets |
| `ragfit/build/` | Asset-Vorabkomprimierung (`precompress-assets.sh` für `.br` und `.gz`) | Brotli, Gzip |
| `modules/openid_connect/` | OIDC-Provider-Integration inkl. `ragfit_admin_group.rb`, `ragfit_login_gate.rb`, `ragfit_revoke_ungated.rb` | `modules/auth_plugins/`, Rails |
| `public/erynoa/1.1.1/` | Vendorter Erynoa-Header (MIT, geprüft gegen `SHA256SUMS`) | Statisches CSS/SVG |
| `frontend/` & `package.json` | Angular / TypeScript Frontend-Workspace (`npm` Skripte) | Node.js 22, npm |

## Domain language

| Term | Meaning |
|------|---------|
| **`RagFit \| *` (`W8`)** | Souveräne 7-schichtige (`L0`–`L6`) Agent-First-Plattform-Dienstfamilie der ErynoaGroup |
| **GPLv3-Lizenzisolation** | Architektonische Trennung: `RagFit \| Plan` bleibt ein reiner GPLv3-Dienst ohne eincompilierte proprietäre SDKs; Bus-Integration erfolgt über die externe `ragfit-plan-bridge` |
| **`ragfit-plan-bridge`** | Externes, zustandsloses Sidecar außerhalb des GPLv3-Prozesses, das OpenProject-Webhooks in `RagFitEventEnvelopeV1`-Nachrichten auf dem NATS-Stream `RAGFIT_PLAN` übersetzt |
| **Full Team Claim (`<org>:<team>`)** | Verbindliches Autorisierungsformat (z. B. `ErynoaGroup:plan-user`); bloße Organisationsnamen werden fail-closed abgewiesen |
| **Patch-Serie (`ragfit/patches/`)** | Nummerierte Git-Patches (`0001`..`0005`), die alle RagFit-Anpassungen kapseln und gegen `CHANGES-RAGFIT.md` geprüft werden |

## Tooling & commands

```bash
nix develop                  # Hermetische DevShell (Ruby 3.4, Node.js 22, just, jq, git, PostgreSQL)
just --list                  # Alle verfügbaren Rezepte anzeigen
just doctor                  # Erynoa-Healthcheck (leak-guard, asset-guard, notice-guard, patches, Strukturprüfung)
just image                   # Leichtgewichtigen Rootless-OCI-Container per Nix bauen (nix build .#container)
just build-image             # Alias für just image
just ci-quick                # Schnelle CI-Prüfung (leak-guard-test, leak-guard, trigger-check, lint-workflows, patches, asset-guard, notice-guard)
just ci                      # Vollständige lokale CI inkl. RuboCop/ERB-Lint, Lizenzprüfung, Image-Build und SBOM
npm ci                       # Frontend-Werkzeuge und Linters aus package-lock.json installieren
bundle exec rspec            # Gezielte RSpec-Tests für OIDC-Gate, Admin-Group, Revoke und Erynoa-Header ausführen
```

## Skills & surface

| Area | Skill / SSOT |
|------|--------------|
| Project doctrine & gate | `./erynoa.md` · skill `erynoa-md` |
| Architecture & docs map | `./docs/README.md` · `./docs/ARCHITECTURE.md` · skill `erynoa-docs` |
| Feature & product workflows | skill `erynoa-project` (`pipeline=vp-*`) |
| Global Agent Surface SSOT | `https://github.com/ErynoaGroup/.ai-harness.git` (`$AGENT_SURFACE_ROOT`) · skill `agent-surface` |
| Org Repository Registry | `https://github.com/ErynoaGroup/.repo-index.git` (`$REPO_INDEX_ROOT`) · skill `repo-index` |

## Provider adapters

Alle acht Erynoa-Konsumenten (Claude, Grok, Codex, Copilot, Hermes, OpenClaw, Kimi, Cursor) lesen diese Datei als kanonische Quelle über dünne Adapter-Pointer in:
- [AGENTS.md](./AGENTS.md)
- [CLAUDE.md](./CLAUDE.md) und [.claude/CLAUDE.md](./.claude/CLAUDE.md)
- [.github/copilot-instructions.md](./.github/copilot-instructions.md)

## Open questions

- [ ] Produktivschaltung des externen `ragfit-plan-bridge`-Sidecars für bidirektionale PR-/WorkPackage-Synchronisation auf Stream `RAGFIT_PLAN`.
- [ ] Upgrade des vendorten Erynoa-Headers von `1.1.1` auf `1.1.4` analog zu `RagFit | Source` und `RagFit | Docs`.
- [ ] Automatisierte Prüfung der Patch-Anwendbarkeit gegen kommende OpenProject-Minor-Releases im Sync-Workflow.
