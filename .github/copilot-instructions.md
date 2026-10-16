<!-- AGENT-SURFACE-SSOT:BEGIN -->
# GitHub Copilot — repository instructions (`RagFit | Plan`)

You are working in a repository that uses the **Erynoa Agent Surface SSOT** for portable skills and plugins shared across eight consumers: Claude, Grok, Codex, Copilot, Hermes, OpenClaw, Kimi, and Cursor.

## Mandatory — project doctrine & architecture

- **Read and follow** root [`erynoa.md`](../erynoa.md) (canonical agent handbook for this repo).
- **Read** [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) for the RagFit v4.0 6-layer architecture, GPLv3 license isolation via `ragfit-plan-bridge`, and boundary rules.
- Keep this file thin; depth lives in `erynoa.md` and `docs/ARCHITECTURE.md`.

<!-- ERYNOA-DOCTRINE:BEGIN -->
## Erynoa Agent Law (R0–R10 · DynHom)

- **R0 Erynoa First:** `github.com/ErynoaGroup/*` only for Erynoa work.
- **R1 Cognee Memory:** read-only via `cognee-recall`; Git wins on contradiction.
- **R2 DynHom:** maximal homogen (same homes/contracts) · maximal dynamisch (signal-bound depth).
- **R3 Portable Paths:** remote + `$ENV` + git root — never `/Users/…` in doctrine.
- **R4 Repo Doctrine:** `erynoa.md` Planner first · `erynoa-gate` PASS · register in `.repo-index`.
- **R5 Surface SSOT:** edit only in `ErynoaGroup/.ai-harness` (`$AGENT_SURFACE_ROOT`).
- **R6 Voice:** Craft Edge register — concise, path-backed, no AI-slop.
- **R7 Verify:** tools > guessing · done = evidence (`just doctor`, `just ci-quick`) · ship only on explicit word.
- **R8 Context Pull:** pull-only context sync on workstations/labs.
- **R9 Primat Vorgehen:** product/project intent routes via primary skill `erynoa-project` + `pipeline=vp-*`.
- **R10 Research Corpus:** research catalogs stay in research repos with EGK cross-links.
<!-- ERYNOA-DOCTRINE:END -->

## Mandatory — Erynoa First + Leak-Guard

- Erynoa remotes live under **`github.com/ErynoaGroup/*`** only.
- **Never** hardcode absolute user paths (`/Users/…`, fixed Mac/Linux portfolio trees) into doctrine as SSOT.
- **Leak-Guard (`ragfit/ci/leak-guard.sh`):** Never write at-mentions before words (except `@sha256:` image digests), internal domains, or private IP addresses.

## Also read

- Root [`erynoa.md`](../erynoa.md) (full doctrine)
- [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) (6-layer system architecture)
- Root [`AGENTS.md`](../AGENTS.md) / [`CLAUDE.md`](../CLAUDE.md) (adapters + surface block)
<!-- AGENT-SURFACE-SSOT:END -->
