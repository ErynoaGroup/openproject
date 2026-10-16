# RagFit | Plan — Roadmap (`docs/work/ROADMAP.md`)

> **Work-Root:** `docs/work/` (`specs/`, `plans/`, `notes/`)  
> **System of Record:** `RagFit | Plan` (Schicht L3 Operative Domain Core · GPLv3)

---

## Abgeschlossene Meilensteine

| ID | Thema | Status | Nachweis |
|---|---|---|---|
| **PLN-01** | Fork-Aufbau auf Basis OpenProject `v17.9.1`, OIDC SSO-Unlock (`0001`), Release-Tag-CI (`erynoa-build.yml`), Cosign & SLSA v1 Provenance | Done | `ragfit/patches/0001-sso-unlock.patch`, `CHANGES-RAGFIT.md` |
| **PLN-02** | OIDC Admin-Group-Synchronisation (`0002`) und Fail-Closed Login-Gate (`0003`) auf vollständige `<org>:<team>`-Claims inkl. Rollout-Revoke-Task | Done | `ragfit/patches/0002-oidc-admin-group.patch`, `ragfit/patches/0003-oidc-login-gate.patch` |
| **PLN-03** | Synchroner E2E-User-Cleanup-Task (`0004`) und Asset-Vorabkomprimierung (`.br`/`.gz`) im Image-Build | Done | `ragfit/patches/0004-e2e-user-cleanup.patch`, `ragfit/build/precompress-assets.sh` |
| **PLN-04** | Integration der vendorten Erynoa-Header-Navigationsleiste (`0005`, `public/erynoa/1.1.1/`) und Code-sensitiver Leak-Guard (`leak-guard-code.pl`) | Done | `ragfit/patches/0005-erynoa-header.patch`, `ragfit/ci/leak-guard.sh` |
| **PLN-05** | Erynoa-Standardisierung (`erynoa.md`, Adapter, 7-Schichten-Architekturdokumentation (`L0`–`L6`), Upstream-Ballast-Bereinigung, leichtgewichtiger Nix-OCI-Container `nix build .#container`) | Done | `erynoa.md`, `flake.nix`, `justfile`, `docs/ARCHITECTURE.md` |

---

## Aktive & Kommende Arbeitspakete

| ID | Thema | Zielschicht | Status |
|---|---|---|---|
| **PLN-06 (`BRIDGE-1`)** | Produktivsetzung des externen `ragfit-plan-bridge`-Sidecars für HMAC-verifizierte Webhook-Übersetzung nach `ragfit-events` (`ragfit.plan.>`) (`plan.work_package.*.v1`, `plan.sprint.*.v1`) | L3 (`Plan`) → L2 (`Bus`) | Planned (`docs/ARCHITECTURE.md` §3) |
| **PLN-07 (`HEADER-1.1.4`)** | Aktualisierung des vendorten Erynoa-Headers von `1.1.1` auf `1.1.4` inkl. `SHA256SUMS`-Prüfung | L3 (`Plan`) / L5 | Planned |
| **PLN-08 (`SYNC-NEXT`)** | Automatisierter Rebase-Check der Patch-Serie `0001`..`0005` gegen kommende OpenProject-Releases | CI / Maintenance | Planned |
