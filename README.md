<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="ragfit/brand/ragfit-by-en-stacked-white-transparent.png">
    <img src="ragfit/brand/ragfit-by-en-stacked-transparent.png" alt="RagFit" width="240">
  </picture>
</p>

# RagFit | Plan

RagFit | Plan is the project management component of RagFit: work packages, boards, roadmaps,
time tracking and documents for teams that run their own infrastructure.

Based on OpenProject (GPLv3). This repository is a modified version; it is not affiliated with or
endorsed by OpenProject GmbH. License and copyright notices are in [LICENSE](LICENSE),
[COPYRIGHT](COPYRIGHT) and [COPYRIGHT_short](COPYRIGHT_short). All changes are listed with date in
[CHANGES-RAGFIT.md](CHANGES-RAGFIT.md).

## Purpose

RagFit | Plan provides planning and tracking inside RagFit. It keeps the upstream feature set and
adds only what is needed to run as part of RagFit: single sign-on through RagFit | Source and a
release-only build pipeline. Upstream releases are merged regularly.

## Architecture

RagFit consists of separate services that communicate only over network APIs:

| Component | Role |
|-----------|------|
| RagFit \| Source | Code hosting, identity and single sign-on (OpenID Connect provider), based on Gitea |
| RagFit \| Plan | Project management (this repository) |
| RagFit \| Memory | Knowledge and retrieval service, based on Cognee |
| RagFit \| Docs | Documentation |

- **Login:** RagFit | Plan authenticates users only through RagFit | Source via OpenID Connect.
- **Permissions:** project membership and roles are mirrored from RagFit | Source. RagFit | Source
  is the single place where access is granted or revoked.
- **No shared code:** the components do not share source code; each keeps its own license.

## Single sign-on patch

Upstream OpenProject restricts the setup of OpenID Connect providers to its commercial edition.
RagFit | Plan removes that restriction for OpenID Connect only, as permitted by the GPLv3
(sections 7 and 10). The change is kept small and separate:

- Patch: [ragfit/patches/0001-sso-unlock.patch](ragfit/patches/0001-sso-unlock.patch), details in
  [CHANGES-RAGFIT.md](CHANGES-RAGFIT.md).
- Only OpenID Connect provider setup and login are affected. SAML and all other features of the
  commercial edition remain restricted exactly as upstream.
- No license tokens are created, simulated or distributed; the token handling itself is unchanged.
- RagFit | Plan does not offer, claim or contain any OpenProject Enterprise features or support.

The patch is re-checked against every upstream release before it is merged.

## Build and release

Images are built only for deliberate releases:

- **Trigger:** release tags `vX.Y.Z-ragfit.N` (for example `v17.9.1-ragfit.1`) or a manual run.
  Pushes and pull requests do not build. The tag version must match `lib/open_project/version.rb`.
- **Runners:** GitHub-hosted runners only.
- **Platforms:** multi-architecture images (`linux/amd64`, `linux/arm64`).
- **Supply chain:** each image is signed with cosign (keyless), and an SPDX SBOM is generated and
  attached as a signed attestation.
- **Image:** `ghcr.io/erynoagroup/ragfit-plan`. Deploy by digest, not by tag.

Local commands (see [justfile](justfile) and [README-RAGFIT-CI.md](README-RAGFIT-CI.md)):

```sh
just ci-quick          # leak guard, workflow lint, patch series, asset and notice guards
just ci                # full local CI incl. image build without push and SBOM check
just release 17.9.1-ragfit.1   # create and push the release tag; CI builds, signs and publishes
```

Verify an image:

```sh
cosign verify ghcr.io/erynoagroup/ragfit-plan@sha256:<digest> \
  --certificate-identity-regexp '^https://github.com/ErynoaGroup/(openproject|ragfit-plan)/\.github/workflows/erynoa-build\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Deployment

RagFit | Plan is deployed with Argo CD from a separate configuration repository. That configuration
references the image by digest and supplies environment-specific values (hostnames, OpenID Connect
client, database, storage) from secrets at runtime. This repository contains no environment-specific
configuration.

## Upstream sync

A scheduled workflow fetches upstream releases daily and opens a pull request for each new release.
It never builds or publishes images; upstream tags do not match the release trigger. Each sync
pull request is reviewed, the single sign-on patch is re-checked, and a release tag is set
afterwards.

## License

RagFit | Plan is licensed under the GNU General Public License version 3 (GPLv3), like the work it is
based on; parts are available under GPLv2 or later. See [LICENSE](LICENSE), [COPYRIGHT](COPYRIGHT)
and [COPYRIGHT_short](COPYRIGHT_short), which are kept unchanged, including the notices of the
ChiliProject and Redmine projects that OpenProject derives from. File headers of upstream files are
kept unchanged. Modified files are listed in [CHANGES-RAGFIT.md](CHANGES-RAGFIT.md).

The source code for every published image is the release tag it was built from, including the
Dockerfile and build workflows.

"OpenProject" is a trademark of its owner and is used here only to describe the origin of this
software.

The RagFit name and logo are brand assets of Erynoa and are not licensed under the GPLv3. Redistributed or modified versions must remove them unless Erynoa grants permission. Provenance of the logo files: [ragfit/brand/PROVENANCE.md](ragfit/brand/PROVENANCE.md).

## Third-party credits

Third-party attributions, including the OpenProject icon font (CC BY 3.0), are listed in [ATTRIBUTION.md](ATTRIBUTION.md).

## Security

See [SECURITY.md](SECURITY.md).
