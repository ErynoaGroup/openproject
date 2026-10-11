# RagFit | Plan – changes to OpenProject

This repository is a modified version of OpenProject (GPL-3.0-only, © OpenProject GmbH).
Per GPLv3 §5(a), all modifications are listed here with date. Upstream notices are kept unchanged.

## 2026-10-10 — 0001 sso-unlock (branch `erynoa/sso-unlock`)

**What:** OpenID Connect provider setup and OIDC login work without a token.
Only the OIDC module is affected; SAML and all other token-gated features are unchanged.

- `modules/auth_plugins/lib/open_project/plugins/auth_plugin.rb`: `filtered_strategy?` also lets `:openid_connect` strategies through.
- `modules/openid_connect/app/controllers/openid_connect/providers_controller.rb`: `check_ee` before_action removed.
- `modules/openid_connect/app/views/openid_connect/providers/index.html.erb`: add button no longer disabled, upsell banner removed.
- `modules/openid_connect/lib/open_project/openid_connect/engine.rb`: admin menu entry no longer marked as token feature.

No tokens are created or simulated; the license token class itself is untouched.

**Why:** RagFit | Plan logs in through RagFit | Source (OIDC). ErynoaGroup holds no commercial
OpenProject contract or license (confirmed by the maintainers, 2026-10-10).
GPLv3 §10 grants every recipient the right to modify and run the program; the code is GPLv3
and no further restrictions may be imposed (§7, §10). Patch file: `ragfit/patches/0001-sso-unlock.patch`.

## 2026-10-11 — CI: build only on release tags

**What:** Images are built, signed and published only for release tags `vX.Y.Z-ragfit.N` or a manual run.
- `.github/workflows/erynoa-build.yml`: build on push to `main` disabled (commented out, marker `#RAGFIT-OFF# `); triggers are tags `v*-ragfit.*` and `workflow_dispatch`; the tag must match `lib/open_project/version.rb`; new `guard` job (leak guard, patch check) runs before the build.
- `.github/workflows/erynoa-upstream-sync.yml`: daily schedule unchanged, never builds; upstream tags `vX.Y.Z` do not match the release trigger.
- All other workflows (upstream build/publish, lint, test, scan, sync and bot workflows): automatic triggers disabled with the same marker; `workflow_dispatch` kept or added.
- `test-core.yml`: third-party runner replaced by `ubuntu-latest` (original kept with marker `#RAGFIT-RUNNER# `); third-party `runs-on/action` disabled, `runs-on/cache` replaced by `actions/cache`.
- `erynoa-build`: `workflow_dispatch` input `guard_only` (default true) runs only the guard job, no build or push.
- New `ragfit/ci/trigger-check.sh` (guard job, `just ci-quick`): fails on active automatic triggers other than the release tag push and the upstream sync schedule, and on non-GitHub-hosted runner labels.
- New: `justfile` (`just release`, `just ci`, `just ci-quick`, `just ci-triggers`, `just trigger-check`), `ragfit/ci/leak-guard.sh`, `README-RAGFIT-CI.md` (how to re-enable triggers).

**Why:** Builds only for deliberate releases on GitHub-hosted runners; synced upstream tags never publish upstream code under this repository.

## 2026-10-11 — Rename to RagFit | Plan, new README

**What:** Repository and image renamed from `openproject` to `ragfit-plan`.
- `README.md`: replaced by the RagFit | Plan README (purpose, architecture, SSO patch, build, deployment, upstream sync, license, third-party credits). The upstream README is available in upstream releases.
- `.github/workflows/erynoa-build.yml`: image `ghcr.io/erynoagroup/ragfit-plan`; SBOM artifact renamed; OCI title/description labels added; cosign identity check accepts the old and the new repository name. Build cache scopes unchanged.
- `justfile`: local CI image name `ragfit-plan-ci`; `ci-quick` also runs `asset-guard` and `notice-guard`.
- New: `ragfit/brand/` (unmodified RagFit logo files with `PROVENANCE.md`), `ragfit/ci/asset-guard.sh`, `ragfit/ci/notice-guard.sh`.

**Why:** Product name RagFit | Plan; upstream name and logo are not used as product branding.

## 2026-10-11 — Attribution, security policy, brand note

**What:** Third-party credits moved to `ATTRIBUTION.md`; `SECURITY.md` replaced by a policy using GitHub private vulnerability reporting; README brand note on the RagFit name and logo; `ragfit/ci/notice-guard.sh` fails in CI when no upstream tag is available.

**Why:** Keep required attributions in one place and give a reporting path for this repository.

## 2026-10-11 — Guard job: asset and notice guards

**What:** `erynoa-build.yml` guard job runs `ragfit/ci/asset-guard.sh` and `ragfit/ci/notice-guard.sh` (upstream tag from `lib/open_project/version.rb`, fetched shallow); `notice-guard.sh` ignores `-ragfit` release tags when looking up the upstream tag; README: RagFit | Source is based on Gitea.

**Why:** License notices and brand assets are checked on every guarded run.

## 2026-10-11 — Release versioning: own SemVer

**What:** Release tags are `ragfit-plan-vX.Y.Z` (own semantic versioning, first release `0.1.0`), set by `just release <major|minor|patch>`.
- `.github/workflows/erynoa-build.yml`: trigger `ragfit-plan-v*`; `meta` validates `ragfit-plan-vX.Y.Z` and no longer requires the tag to match `lib/open_project/version.rb`; image tag `ragfit-plan:X.Y.Z`; OCI labels `org.opencontainers.image.base.name` and `ragfit.upstream` record the upstream base; new `release` job creates the GitHub release "RagFit | Plan vX.Y.Z" with image digest and upstream base.
- `ragfit/ci/trigger-check.sh`: allowlist `ragfit-plan-v*`. `ragfit/ci/notice-guard.sh`: compares only against upstream `vX.Y.Z` tags.
- `justfile`, `README-RAGFIT-CI.md`, `README.md`: new release command and convention.
- The earlier tag `v17.9.1-ragfit.1` is kept and no longer matches the trigger.

**Upstream base at this change:** openproject@v17.9.1/c7ec3ef.
