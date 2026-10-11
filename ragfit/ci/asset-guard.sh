#!/usr/bin/env bash
# Verifies that brand assets are byte-identical to the hashes recorded in ragfit/brand/PROVENANCE.md.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0; n=0
while IFS='|' read -r _ file hash _; do
  file=$(echo "$file" | tr -d ' `'); hash=$(echo "$hash" | tr -d ' `')
  [[ "$file" == *.png ]] || continue
  n=$((n+1))
  actual=$(sha256sum "ragfit/brand/$file" 2>/dev/null | cut -d' ' -f1 || true)
  if [[ "$actual" != "$hash" ]]; then echo "asset-guard: $file differs from PROVENANCE.md" >&2; fail=1; fi
done < ragfit/brand/PROVENANCE.md
[[ $n -gt 0 ]] || { echo "asset-guard: no assets listed" >&2; exit 1; }
[[ $fail -eq 0 ]] && echo "asset-guard OK ($n files)"
exit $fail
