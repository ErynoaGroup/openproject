# RagFit changes to OpenProject (ErynoaGroup/openproject → RagFit | Plan)

This repository is a modified version of OpenProject (GPL-3.0-only, © OpenProject GmbH).
Per GPLv3 §5(a), all modifications are listed here with date. Upstream notices are kept unchanged.

## 2026-10-10 — 0001 sso-unlock (branch `erynoa/sso-unlock`)

**What:** OpenID Connect provider setup and OIDC login work without a token.
Only the OIDC module is affected; SAML and all other token-gated features are unchanged.

- `modules/auth_plugins/lib/open_project/plugins/auth_plugin.rb`: `filtered_strategy?` also lets `:openid_connect` strategies through.
- `modules/openid_connect/app/controllers/openid_connect/providers_controller.rb`: `check_ee` before_action removed.
- `modules/openid_connect/app/views/openid_connect/providers/index.html.erb`: add button no longer disabled, upsell banner removed.
- `modules/openid_connect/lib/open_project/openid_connect/engine.rb`: admin menu entry no longer marked as token feature.

No tokens are created or simulated; `EnterpriseToken` itself is untouched.

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
