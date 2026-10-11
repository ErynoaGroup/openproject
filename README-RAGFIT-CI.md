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
Automatic triggers (`push`, `pull_request`, `schedule`) were **commented out, not deleted**, in:
`erynoa-build.yml` (push to `main`), `core-docker-release.yml`, `hocuspocus-docker.yml`, `packager.yml`,
`continuous-delivery.yml`, `pullpreview.yml`. Each disabled line starts with the marker `#RAGFIT-OFF# `.

- List: `just ci-triggers`
- Re-enable one workflow: `just ci-triggers on packager.yml` (removes the marker; then review, `actionlint`, commit via PR)
- Without just: `sed -i 's/^#RAGFIT-OFF# //' .github/workflows/<file>`
- Disable again: prefix the trigger lines under `on:` with `#RAGFIT-OFF# `.

Notes:
- Re-enabling push-to-`main` in `erynoa-build.yml` also needs the `meta` job to accept non-tag refs (it currently rejects anything that is not `vX.Y.Z-ragfit.N`).
- Upstream publish workflows target upstream registries/infrastructure and need upstream secrets; re-enable only with a clear reason.
