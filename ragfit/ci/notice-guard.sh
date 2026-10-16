#!/usr/bin/env bash
# Fails if upstream license/notice files differ from the last synced upstream tag,
# and prints the files changed relative to upstream (input for CHANGES-RAGFIT.md).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
base=${UPSTREAM_REF:-$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' --exclude 'ragfit-plan-v*' 2>/dev/null || true)}
# Upstream tags only (vX.Y.Z); own release tags ragfit-plan-v* and legacy vX.Y.Z-ragfit.N are excluded.
if [[ -z "$base" ]]; then
  if [[ "${CI:-}" == "true" ]]; then echo "notice-guard: no upstream tag found in CI (fetch tags or set UPSTREAM_REF)" >&2; exit 1; fi
  echo "notice-guard: WARNING no upstream tag found (shallow clone?); skipping" >&2; exit 0
fi
fail=0
for f in LICENSE COPYRIGHT COPYRIGHT_short; do
  git diff --quiet "$base" -- "$f" || { echo "notice-guard: $f changed vs $base" >&2; fail=1; }
done
echo "Files changed vs $base:"
git diff --name-only "$base" -- . ':!ragfit' ':!.github' ':!.erynoa' ':!CHANGES-RAGFIT.md' ':!README*.md' ':!justfile' ':!flake.nix' ':!flake.lock' ':!erynoa.md' ':!AGENTS.md' ':!CLAUDE.md' ':!.claude/**' ':!.github/copilot-instructions.md' ':!docs/**' ':!nix/**' ':!publiccode.yml' ':!publiccode_logo.svg' ':!GitHub-tab-new.png' ':!screenshots/**' ':!CODE_OF_CONDUCT.md' ':!CONTRIBUTING.md' ':!SECURITY.md' ':!CHANGELOG.md' ':!.env.test*' ':!docker/dev/**' ':!app/AGENTS.md' ':!app/CLAUDE.md' ':!config/AGENTS.md' ':!config/CLAUDE.md' ':!db/AGENTS.md' ':!db/CLAUDE.md' ':!spec/AGENTS.md' ':!spec/CLAUDE.md' | sed 's/^/  /'
[[ $fail -eq 0 ]] && echo "notice-guard OK"
exit $fail
