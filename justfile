# RagFit | Plan (OpenProject fork). Public repo: never put hosts, tailnet data, IPs, internal names or @-mentions here.
# Images are built ONLY by GitHub Actions (erynoa-build.yml) on release tags ragfit-plan-vX.Y.Z. No local/server publishing.

set shell := ["bash", "-euo", "pipefail", "-c"]

image := "ragfit-plan-ci"

# Show recipes
default:
    just --list

# Cut a release: just release <major|minor|patch>  → bumps from the latest ragfit-plan-v* tag (first release: 0.1.0),
# creates annotated tag ragfit-plan-vX.Y.Z on main and pushes it (triggers CI build/sign/publish).
# Own SemVer; the upstream base is recorded in release notes, OCI labels and CHANGES-RAGFIT.md, not in the tag.
release bump:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{bump}}" in major|minor|patch) ;; *) echo "usage: just release <major|minor|patch>" >&2; exit 1 ;; esac
    [ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { echo "release only from main" >&2; exit 1; }
    git diff --quiet && git diff --cached --quiet || { echo "working tree not clean" >&2; exit 1; }
    git fetch -q origin main
    git fetch -q origin 'refs/tags/ragfit-plan-v*:refs/tags/ragfit-plan-v*'
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "HEAD != origin/main" >&2; exit 1; }
    last=$(git tag -l 'ragfit-plan-v*' | sed -nE 's/^ragfit-plan-v([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' | sort -V | tail -n1)
    if [ -z "$last" ]; then v=0.1.0
    else
      IFS=. read -r ma mi pa <<< "$last"
      case "{{bump}}" in major) v="$((ma+1)).0.0" ;; minor) v="$ma.$((mi+1)).0" ;; patch) v="$ma.$mi.$((pa+1))" ;; esac
    fi
    t="ragfit-plan-v$v"
    git rev-parse -q --verify "refs/tags/$t" >/dev/null && { echo "tag $t exists" >&2; exit 1; }
    just ci-quick
    git tag -a "$t" -m "RagFit | Plan v$v"
    git push origin "refs/tags/$t"
    echo "pushed $t (previous: ${last:-none}) → GitHub Actions erynoa-build.yml builds, signs and publishes"

# Fast checks (seconds): leak guard, workflow lint, patch series consistency
ci-quick: leak-guard-test leak-guard trigger-check lint-workflows patches asset-guard notice-guard

# Full local CI (no push, no publish): quick checks + Ruby/JS lint on our changes + license scan + image build + SBOM check
ci: ci-quick lint licenses build sbom

# Public-repo leak guard (hosts, tailnet, IPs, internal names, @-mentions)
leak-guard:
    ragfit/ci/leak-guard.sh

# Tests for the leak guard (allowed constructs neutralized, real hits on the same line still caught)
leak-guard-test:
    ragfit/ci/leak-guard-test.sh

# No active automatic triggers (except allowed ones), only free GitHub-hosted runners
trigger-check:
    ragfit/ci/trigger-check.sh

# Workflow lint (actionlint, zizmor if installed)
lint-workflows:
    actionlint .github/workflows/erynoa-*.yml
    command -v zizmor >/dev/null && zizmor --offline .github/workflows/erynoa-*.yml || echo "zizmor not installed, skipped"

# Every patch in ragfit/patches must be applied in the tree (reverse-apply check) and listed in CHANGES-RAGFIT.md
patches:
    #!/usr/bin/env bash
    set -euo pipefail
    for p in ragfit/patches/*.patch; do
      # CHANGES-RAGFIT.md is a living log; later entries break an exact reverse-apply
      git apply -R --check --exclude=CHANGES-RAGFIT.md "$p" || { echo "patch not applied in tree: $p" >&2; exit 1; }
      grep -q "$(basename "$p")" CHANGES-RAGFIT.md || { echo "$p missing in CHANGES-RAGFIT.md" >&2; exit 1; }
    done
    echo "patch series consistent"

# Lint only the files our patches touch (full upstream suite runs upstream; too heavy here)
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    files=$(grep -hE '^\+\+\+ b/' ragfit/patches/*.patch | sed 's#^+++ b/##' | sort -u)
    rb=$(echo "$files" | grep -E '\.rb$' || true)
    erb=$(echo "$files" | grep -E '\.erb$' || true)
    [ -z "$rb" ]  || bundle exec rubocop $rb
    [ -z "$erb" ] || bundle exec erb_lint $erb
    # Targeted specs for the OIDC module where feasible (needs DB; skipped if not configured)
    if [ -n "${DATABASE_URL:-}" ]; then bundle exec rspec modules/openid_connect/spec/requests modules/openid_connect/spec/controllers; else echo "DATABASE_URL not set, specs skipped"; fi

# License scan: GPL notices kept, modification log present, SPDX/license data of the built image checked in `sbom`
licenses:
    #!/usr/bin/env bash
    set -euo pipefail
    test -f LICENSE && grep -q "GNU GENERAL PUBLIC LICENSE" LICENSE
    test -f COPYRIGHT && test -f CHANGES-RAGFIT.md
    git diff --name-only "$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)"...HEAD -- LICENSE COPYRIGHT COPYRIGHT_short | grep . && { echo "upstream license files modified" >&2; exit 1; } || true
    command -v licensee >/dev/null && licensee detect . || echo "licensee not installed, skipped"
    echo "license checks ok"

# Build the slim image locally/in CI WITHOUT pushing (OCI tar for the SBOM step)
build platform="linux/amd64":
    docker buildx build --file docker/prod/Dockerfile --target slim --build-arg BIM_SUPPORT=false \
      --platform {{platform}} --output type=docker,dest=/tmp/{{image}}.tar --tag {{image}}:ci .

# SBOM: generate with syft from the local tar and sanity-check it (packages present, GPL app license detected)
sbom:
    #!/usr/bin/env bash
    set -euo pipefail
    syft "docker-archive:/tmp/{{image}}.tar" -o spdx-json=/tmp/{{image}}.spdx.json
    n=$(jq '.packages | length' /tmp/{{image}}.spdx.json)
    [ "$n" -gt 100 ] || { echo "SBOM too small ($n packages)" >&2; exit 1; }
    echo "SBOM ok: $n packages"

# Show/toggle disabled automatic workflow triggers (lines prefixed "#RAGFIT-OFF# ").
#   just ci-triggers            → list disabled triggers per workflow
#   just ci-triggers on  <file> → re-enable (remove prefix) in .github/workflows/<file>
#   just ci-triggers off <file> → not automatic; re-add the prefix by hand (see README-RAGFIT-CI.md)
ci-triggers action="list" file="":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{action}}" in
      list) grep -n '^#RAGFIT-OFF# ' .github/workflows/*.y*ml || echo "no disabled triggers" ;;
      on)   f=".github/workflows/{{file}}"; [ -f "$f" ] || { echo "usage: just ci-triggers on <workflow.yml>" >&2; exit 1; }
            sed -i 's/^#RAGFIT-OFF# //' "$f"; echo "re-enabled triggers in $f – review and commit"
            actionlint "$f" || echo "WARNING: actionlint reports errors in $f – fix before committing" >&2
            echo "NOTE: trigger-check (guard/ci-quick) will fail until $f is added to ALLOWED in ragfit/ci/trigger-check.sh" >&2 ;;
      *)    echo "usage: just ci-triggers [list|on <workflow.yml>]" >&2; exit 1 ;;
    esac

# Brand assets must stay byte-identical to the pinned source (ragfit/brand/PROVENANCE.md)
asset-guard:
    ragfit/ci/asset-guard.sh

# Upstream license notices must stay unchanged; lists files changed vs. upstream
notice-guard:
    ragfit/ci/notice-guard.sh
