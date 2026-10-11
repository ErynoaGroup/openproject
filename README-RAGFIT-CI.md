# RagFit | Plan – CI and releases

Images are built, signed and published **only** by `.github/workflows/erynoa-build.yml`, on GitHub-hosted runners, for:
- a pushed release tag `vX.Y.Z-ragfit.N` (`just release X.Y.Z-ragfit.N`), or
- a manual run (`workflow_dispatch`, input `ref` = release tag).

Plain upstream tags `vX.Y.Z` (pushed by the daily upstream sync) do **not** match `v*-ragfit.*` and never build.
`erynoa-upstream-sync.yml` keeps its daily schedule and only opens a sync PR; merging it does not build.

## Local checks
- `just ci-quick` – leak guard (public repo: no hosts, private network data, internal names, @-mentions), workflow lint, patch series.
- `just ci` – plus lint of patched files, license checks, local image build without push, SBOM check.

## Disabled triggers and how to re-enable them
All automatic triggers (`push`, `pull_request`, `pull_request_target`, `schedule`, `issue_comment`, …) are
**commented out, not deleted**, in **every** workflow except the two allowed ones:
- `erynoa-build.yml`: only `push` of tags `v*-ragfit.*` (push to `main` is disabled with the marker),
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
`ubuntu-latest` (original runner lines kept with the marker `#RAGFIT-RUNNER# `). The job is still gated to the upstream
organisation by its `if:` condition and its triggers are disabled, so it does not run in this fork unless adapted.

Leak guard in CI: the guard job scans only our own files (shallow checkout, no upstream tags); diff and commit-message
scans run with `just ci-quick` in a clone with tags. CI fails if the repository secret `RAGFIT_LEAK_EXTRA` is empty.

Notes:
- Re-enabling push-to-`main` in `erynoa-build.yml` also needs the `meta` job to accept non-tag refs (it currently rejects anything that is not `vX.Y.Z-ragfit.N`).
- Upstream publish workflows target upstream registries/infrastructure and need upstream secrets; re-enable only with a clear reason.
