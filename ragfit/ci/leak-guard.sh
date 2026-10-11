#!/usr/bin/env bash
# Leak guard for this PUBLIC fork: no hostnames, tailnet data, private IPs, internal names or @-mentions
# in our own files or in our changes compared to upstream. Upstream files are not scanned (they contain
# upstream e-mail addresses and code annotations), only what we add.
# Usage: ragfit/ci/leak-guard.sh [upstream-ref]   (default: newest vX.Y.Z tag in the repo)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Own paths (always scanned in full)
OWN=(ragfit .erynoa CHANGES-RAGFIT.md README-RAGFIT-CI.md justfile .github/workflows/erynoa-*.yml)

# Patterns (extended regex, case-insensitive)
P_TAILNET='ts\.net|tail[0-9a-f]{6}|magicdns'
P_CGNAT='(^|[^0-9])100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}'
P_PRIVIP='(^|[^0-9.])(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}'
P_MENTION='(^|[[:space:](\[{,;"'"'"'])@[A-Za-z0-9][A-Za-z0-9-]{0,38}([^A-Za-z0-9@./-]|$)'
# Internal names are NOT listed here (that would publish them). Supply them via env
# RAGFIT_LEAK_EXTRA (extended regex), e.g. from a CI secret or a local untracked file.
P_INTERNAL='\.local([^a-z]|$)|\.internal([^a-z]|$)|\.lan([^a-z]|$)'
[ -n "${RAGFIT_LEAK_EXTRA:-}" ] && P_INTERNAL="${P_INTERNAL}|${RAGFIT_LEAK_EXTRA}"
[ -z "${RAGFIT_LEAK_EXTRA:-}" ] && [ -f .ragfit-leak-extra ] && P_INTERNAL="${P_INTERNAL}|$(tr -d '\n' < .ragfit-leak-extra)"
if [ "${RAGFIT_LEAK_REQUIRE_EXTRA:-}" = true ] && [ -z "${RAGFIT_LEAK_EXTRA:-}" ]; then
  echo "leak-guard: RAGFIT_LEAK_EXTRA is empty (repository secret missing) – failing" >&2; exit 1
fi
PATTERN="(${P_TAILNET})|(${P_CGNAT})|(${P_PRIVIP})|(${P_MENTION})|(${P_INTERNAL})"
# Code patches: Ruby instance variables (@provider) look like mentions → no mention check there
PATTERN_CODE="(${P_TAILNET})|(${P_CGNAT})|(${P_PRIVIP})|(${P_INTERNAL})"

# allowlist: digest/action pins (name@sha, @v1) are not mentions
ALLOW='@sha256:|uses: [^ ]+@|users\.noreply\.github\.com'

fail=0
scan() { # stdin: text, $1: label, $2: optional pattern
  local hits
  hits=$(grep -nEi "${2:-$PATTERN}" | grep -vEi "$ALLOW" || true)
  if [ -n "$hits" ]; then echo "LEAK in $1:"; echo "$hits" | sed 's/^/  /'; fail=1; fi
}

for p in "${OWN[@]}"; do
  for f in $(git ls-files -- "$p" 2>/dev/null); do
    [ "$f" = ragfit/ci/leak-guard.sh ] && continue   # contains the patterns themselves
    [ -f "$f" ] || { echo "missing in checkout (sparse?): $f" >&2; fail=1; continue; }
    case "$f" in *.patch) scan "$f" "$PATTERN_CODE" < "$f" ;; *) scan "$f" < "$f" ;; esac
  done
done

base="${1:-$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)}"
if [ -n "$base" ] && git rev-parse -q --verify "${base}^{commit}" >/dev/null && git merge-base "$base" HEAD >/dev/null 2>&1; then
  git diff "${base}"...HEAD -- . ':!ragfit/ci/leak-guard.sh' ':!ragfit/patches' | grep -E '^\+[^+]' | scan "diff ${base}...HEAD (added lines)"
  git diff "${base}"...HEAD -- ragfit/patches | grep -E '^\+[^+]' | scan "patches diff ${base}...HEAD" "$PATTERN_CODE"
  git log --format='%an <%ae>%n%B' "${base}"..HEAD | scan "commit messages ${base}..HEAD"
else
  echo "note: no upstream tag with merge base (shallow clone?), diff/commit-message scan skipped"
fi

[ "$fail" = 0 ] && echo "leak-guard: clean" || { echo "leak-guard: FAILED"; exit 1; }
