# RagFit | Plan – CI and releases

Images are built, signed and published **only** by `.github/workflows/erynoa-build.yml`, on GitHub-hosted runners, for:
- a pushed release tag `ragfit-plan-vX.Y.Z` (`just release <major|minor|patch>`), or
- a manual run (`workflow_dispatch`, input `ref` = release tag).

Versions are our own SemVer (first release `0.1.0`); `just release` bumps from the latest `ragfit-plan-v*` tag.
The upstream base (for example `openproject@v17.9.1/c7ec3ef`) is recorded only in the release notes, the OCI labels
`org.opencontainers.image.base.name` and `ragfit.upstream`, and `CHANGES-RAGFIT.md`.
Each release publishes `ghcr.io/erynoagroup/ragfit-plan:X.Y.Z` (deploy by digest) and a GitHub release "RagFit | Plan vX.Y.Z".

Upstream tags `vX.Y.Z` (pushed by the daily upstream sync) do **not** match `ragfit-plan-v*` and never build.
The legacy tag `v17.9.1-ragfit.1` is kept; it no longer matches the trigger.
`erynoa-upstream-sync.yml` keeps its daily schedule and only opens a sync PR; merging it does not build.

## Local checks
- `just ci-quick` – leak guard (public repo: no hosts, private network data, internal names, @-mentions), workflow lint, patch series.
- `just ci` – plus lint of patched files, license checks, local image build without push, SBOM check.

## Disabled triggers and how to re-enable them
All automatic triggers (`push`, `pull_request`, `pull_request_target`, `schedule`, `issue_comment`, …) are
**commented out, not deleted**, in **every** workflow except the two allowed ones:
- `erynoa-build.yml`: only `push` of tags `ragfit-plan-v*` (push to `main` is disabled with the marker),
- `erynoa-upstream-sync.yml`: daily `schedule`.
Each disabled line starts with the marker `#RAGFIT-OFF# `. Every workflow keeps (or got) `workflow_dispatch`, so it can still be run by hand.

`ragfit/ci/trigger-check.sh` enforces this (guard job and `just ci-quick`): it fails on any other active automatic
trigger and on any runner label that is not a free GitHub-hosted runner.

- List: `just ci-triggers`
- Re-enable one workflow: `just ci-triggers on packager.yml` (removes the marker; then review, `actionlint`, commit via PR)
- Without just: `sed -i 's/^#RAGFIT-OFF# //' .github/workflows/<file>`
- Disable again: prefix the trigger lines under `on:` with `#RAGFIT-OFF# `.
- A deliberately re-enabled trigger must also be added to `ALLOWED` in `ragfit/ci/trigger-check.sh`, otherwise the guard fails.

Runners: free GitHub-hosted runners only. `test-core.yml` upstream uses a third-party runner service; here it runs on
`ubuntu-latest` (original runner lines kept with the marker `#RAGFIT-RUNNER# `). The third-party `runs-on/action` step is disabled and
`runs-on/cache` is replaced by `actions/cache` (same inputs); the originals are kept with the same marker. The job is still gated to the upstream
organisation by its `if:` condition and its triggers are disabled, so it does not run in this fork unless adapted.

Leak guard in CI: the guard job (erynoa-build.yml) and the `leak-guard` job of erynoa-spec.yml run
`ragfit/ci/leak-base-fetch.sh` first: it fetches the upstream tag of `lib/open_project/version.rb` and deepens the
shallow checkout to the merge base, so the diff and commit-message scans (and the commit allowlist) really run;
`RAGFIT_LEAK_REQUIRE_BASE=true` fails the job if they cannot. The guard job fails if the repository secret
`RAGFIT_LEAK_EXTRA` is empty; erynoa-spec.yml uses no secrets and scans without the internal names.
Added lines of code files (Ruby, ERB, JS/TS) get the full check after `ragfit/ci/leak-guard-code.pl` has neutralized
at-sign identifiers in code position (instance variables, decorators); comments, string literals and ERB text outside
`<% %>` are still mention-checked;
in stylesheets CSS at-rules such as `@media` are not mentions, everything else after an at sign still is.

Notes:
- Re-enabling push-to-`main` in `erynoa-build.yml` also needs the `meta` job to accept non-tag refs (it currently rejects anything that is not `ragfit-plan-vX.Y.Z`).
- Upstream publish workflows target upstream registries/infrastructure and need upstream secrets; re-enable only with a clear reason.

## Guard-only run

`erynoa-build` has a `workflow_dispatch` input `guard_only` (default `true`). A manual run with the default only runs
the guard job (leak guard, trigger check, asset and notice guards, patch check) on the given ref; nothing is built or pushed:

    gh workflow run erynoa-build.yml --ref <branch> -f ref=<branch>

A manual release build needs `-f ref=ragfit-plan-vX.Y.Z -f guard_only=false`. Tag pushes always build.
