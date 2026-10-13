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

## 2026-10-11 — Release notes: corresponding source

**What:** The GitHub release notes state the license and the corresponding source (this repository at the release tag). `meta` resolves the upstream tag to its commit for annotated tags. `just release` already creates annotated tags.

**Why:** GPLv3 §6: every published image names where its corresponding source is.

## 2026-10-11 — CI: SLSA v1 provenance attestation

**What:** `.github/workflows/erynoa-build.yml` (`publish` job) adds a keyless `cosign attest --type slsaprovenance1` next to the existing signature and SPDX attestation. The predicate is generated in the workflow and carries the image digest; the step refuses to run for anything but a release tag `ragfit-plan-vX.Y.Z`. The verify step also checks the `slsaprovenance1` attestation, with the identity anchored to the exact release tag ref, and compares the verified provenance subject with the digest the registry resolves for the release tag. The per-arch build digests must match the index manifests. `meta` sets `release=true` only when the workflow runs on a `ragfit-plan-vX.Y.Z` tag ref (tag push, or a dispatch started on that tag); otherwise build, publish and release are skipped. cosign pinned to v3.0.6 via `cosign-release`.

**Why:** Deployments check signature, SPDX SBOM and SLSA provenance by digest before rollout.

## 2026-10-13 — 0002 oidc-admin-group

**What:** The OpenProject admin flag can follow a group in the OIDC `groups` claim, granted and revoked on every login.
- New `modules/openid_connect/lib/open_project/openid_connect/ragfit_admin_group.rb`: with `RAGFIT_OIDC_<PROVIDER>_ADMIN_GROUP` set (provider slug in upper case, e.g. `RAGFIT_OIDC_SOURCE_ADMIN_GROUP`), the OpenID Connect strategy returns `admin: true` when the userinfo `groups` claim contains that group (case-insensitive, exact entry) and `admin: false` when the claim is present without it. Without the variable (or with a blank one) or without a `groups` array nothing is returned and the admin flag stays as it is. Entries in the claim that are not strings are ignored; the claim is read from `groups` or `:groups`.
- Exactly one group per provider: the variable holds a single group name, not a list.
- Only a full team claim `<org>:<team>` is accepted (binding rule 2026-10-13: Source OIDC consumers never authorize on a bare org name). A value without `:` or with an empty part is ignored with a warning in the log, and the admin flag stays unchanged.
- RagFit | Source (Gitea) builds team entries as org name + `:` + lower-case team name, e.g. `ErynoaGroup:platform-admin`. Set the variable to exactly that string (the comparison is case-insensitive and exact, no prefix match).
- `modules/openid_connect/lib/open_project/openid_connect/engine.rb`: prepends the module to `OmniAuth::FlexibleStrategy` (`omniauth_hash_to_user_attributes`, the existing upstream extension point in `Authentication::OmniauthService`), because every strategy instance is extended with `FlexibleStrategy` at runtime and its method would shadow a patch on the strategy class; only OpenID Connect strategies are changed. Upstream `update_admin_flag` then grants or revokes admin on each login.
- New spec `modules/openid_connect/spec/lib/open_project/openid_connect/ragfit_admin_group_spec.rb`.

**Why:** RagFit | Source sends groups as `org` and `org:team` entries but no boolean admin claim; upstream can only map admin from a boolean claim. Patch file: `ragfit/patches/0002-oidc-admin-group.patch`.

## 2026-10-13 — CI: RagFit spec workflow

**What:** New `.github/workflows/erynoa-spec.yml` runs `modules/openid_connect/spec/lib/open_project/openid_connect/ragfit_admin_group_spec.rb` on `ubuntu-24.04` (Postgres service, Ruby from `.ruby-version`, cached bundle, `db:create db:migrate`, no frontend build). Triggers: `pull_request` limited to `modules/openid_connect/**`, `ragfit/**` and the workflow itself, plus `workflow_dispatch`; `permissions: contents: read`; concurrency per ref. `ragfit/ci/trigger-check.sh` allows exactly this trigger (paths only, read-only permissions) and fails on job-level permissions other than `contents: read`/none and on any `secrets.*` or `secrets[...]` use in this workflow. The Postgres service image is pinned by digest.

**Why:** The RagFit patches get a real spec run before merge; free GitHub-hosted runner, no publish rights.

## 2026-10-13 — 0003 oidc-login-gate

**What:** An OpenID Connect login can be limited to members of listed teams.
- New `modules/openid_connect/lib/open_project/openid_connect/ragfit_login_gate.rb`: with `RAGFIT_OIDC_<PROVIDER>_LOGIN_GROUPS` set (comma-separated full team claims, e.g. `RAGFIT_OIDC_SOURCE_LOGIN_GROUPS=ErynoaGroup:plan-user`), a login through that provider is approved only if the userinfo `groups` claim contains one of the teams or the provider's `RAGFIT_OIDC_<PROVIDER>_ADMIN_GROUP`. Otherwise it is rejected with the upstream message "You are not allowed to sign in." and a log line that names only provider and login. A missing `groups` claim is rejected (fail closed).
- Matching: claim entries must be strings and equal a team exactly, case-insensitive (Gitea lower-cases team names; consistent with the admin group). Claim entries are not trimmed, so `" ErynoaGroup:plan-user"` or `"ErynoaGroup:plan-user-x"` do not match. Only the variable's entries are trimmed; entries that are not `<org>:<team>` with non-empty parts are ignored with a warning.
- Without the variable (or without a valid entry) logins behave as upstream; a warning is logged once at boot if no provider has a login gate. Only OpenID Connect providers are gated.
- `modules/openid_connect/lib/open_project/openid_connect/engine.rb`: registers the gate as an `OpenProject::OmniAuth::Authorization` callback (upstream extension point, evaluated in `Authentication::OmniauthAuthHashContract` before any user lookup or creation).
- New spec `modules/openid_connect/spec/lib/open_project/openid_connect/ragfit_login_gate_spec.rb`; `.github/workflows/erynoa-spec.yml` runs it next to the admin-group spec.

**Why:** Binding rule 2026-10-13: Source OIDC consumers authorize only on a full team claim, also at login; a user outside the org could sign in as a normal user. Patch file: `ragfit/patches/0003-oidc-login-gate.patch`.

