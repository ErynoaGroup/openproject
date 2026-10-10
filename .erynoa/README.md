# ErynoaGroup/openproject

Public fork of [opf/openproject](https://github.com/opf/openproject) (GPL-3.0). See [GPL.md](GPL.md).

- `main` = latest upstream stable release tag (currently `v17.9.1`) + **one** extra commit that
  only adds `.erynoa/` and `.github/workflows/erynoa-*.yml`. Upstream code is unchanged.
- `stable/17` and tag `v17.9.1` are 1:1 copies of upstream.
- Upstream workflows are **disabled via the Actions API** (not edited/deleted), so only
  `erynoa-*` workflows run. Re-check after each sync: new upstream workflow files must be
  disabled too (`gh workflow disable <name> -R ErynoaGroup/openproject`).
- `erynoa-build.yml`: on push to `main`, builds the upstream `docker/prod/Dockerfile`
  target `slim` (`BIM_SUPPORT=false`, as upstream `*-slim`) natively on `ubuntu-24.04-arm`
  and `ubuntu-24.04` (no QEMU), publishes a multi-arch index, signs keyless with cosign and
  attaches a syft SPDX SBOM attestation.
  - `ghcr.io/erynoagroup/openproject:<version>-slim` / `:sha-<short>`
- `erynoa-upstream-sync.yml`: daily, opens one PR per new upstream release. See [SYNC.md](SYNC.md).
- Deployment (K9ix, Argo CD) pulls the finished image by digest; nothing is built in Nix.

Verify:

```sh
cosign verify ghcr.io/erynoagroup/openproject@sha256:<digest> \
  --certificate-identity-regexp '^https://github.com/ErynoaGroup/openproject/\.github/workflows/erynoa-build\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
