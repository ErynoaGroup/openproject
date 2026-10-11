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

# Allowed constructs are NEUTRALIZED by replacement on the raw text, never used to skip whole
# lines, so a digest/action pin/noreply address cannot hide a real hit on the same line:
#   @sha256 followed by ':' (img@sha256:<hex>), case-insensitive; in prose it counts as a mention, action pins
#   (uses: owner/repo@ref) and GitHub noreply addresses. Runs BEFORE grep -n adds its N: prefix.
neutralize() {
  sed -E -e 's/@sha256:/_sha256_:/gI' \
         -e 's/(uses:[[:space:]]+[^[:space:]@]+)@([^[:space:]]+)/\1_at_\2/g' \
         -e 's/[A-Za-z0-9._+-]*@users\.noreply\.github\.com/noreply-address/gI'
}

fail=0
# Runs in the PARENT shell (never `... | scan`), so fail=1 survives. Fails closed: grep exit 1 means
# no hits, anything >= 2 (e.g. an invalid RAGFIT_LEAK_EXTRA pattern) fails the guard.
scan() { # stdin: text, $1: label, $2: optional pattern
  local hits rc=0
  hits=$(neutralize | grep -nEi -e "${2:-$PATTERN}") || rc=$?
  if [ "$rc" -ge 2 ]; then echo "leak-guard: ERROR scanning $1 (grep exit $rc, invalid pattern?)" >&2; fail=1; return 0; fi
  if [ -n "$hits" ]; then echo "LEAK in $1:"; echo "$hits" | sed 's/^/  /'; fail=1; fi
  return 0
}
# grep that treats "no match" (exit 1) as success but keeps real errors (>= 2)
grep0() { grep "$@" || [ $? -eq 1 ]; }
# paths: split on / so a mention-like path segment (docs/@alice/) is matched like a word
paths() { sed 's#/# #g'; }
# added_lines: content of added lines inside hunks only (a line whose content starts with '+' shows as '++...'; '+++ ' file headers are outside hunks)
added_lines() { awk '/^diff --git /{h=0; next} /^@@ /{h=1; next} h && /^\+/{print substr($0,2)}'; }

# Test hook (ragfit/ci/leak-guard-test.sh): scan stdin with the real patterns, exit 1 on a hit
if [ "${1:-}" = --stdin ]; then scan stdin; [ "$fail" = 0 ] || exit 1; exit 0; fi

own_files=()
for p in "${OWN[@]}"; do
  mapfile -t -O "${#own_files[@]}" own_files < <(git ls-files -- "$p" 2>/dev/null)
done
for f in "${own_files[@]}"; do
  case "$f" in ragfit/ci/leak-guard.sh|ragfit/ci/leak-guard-test.sh) continue ;; esac   # patterns / test fixtures
  [ -f "$f" ] || { echo "missing in checkout (sparse?): $f" >&2; fail=1; continue; }
  case "$f" in *.patch) scan "$f" "$PATTERN_CODE" < "$f" ;; *) scan "$f" < "$f" ;; esac
done
scan "own file paths" < <(printf '%s\n' "${own_files[@]}" | paths)

base="${1:-$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)}"
if [ -n "$base" ] && git rev-parse -q --verify "${base}^{commit}" >/dev/null && git merge-base "$base" HEAD >/dev/null 2>&1; then
  # strip the diff "+" so a mention at the start of an added line still matches
  added=$(git diff "${base}"...HEAD -- . ':!ragfit/ci/leak-guard.sh' ':!ragfit/ci/leak-guard-test.sh' ':!ragfit/patches' | added_lines)
  scan "diff ${base}...HEAD (added lines)" <<<"$added"
  added=$(git diff "${base}"...HEAD -- ragfit/patches | added_lines)
  scan "patches diff ${base}...HEAD" "$PATTERN_CODE" <<<"$added"
  changed=$(git diff --name-only "${base}"...HEAD)
  scan "changed paths ${base}...HEAD" < <(printf '%s\n' "$changed" | paths)
  # Commits listed in leak-guard-allow-commits (full SHA, one per line) skip ONLY the message scan;
  # their files, diff and paths are still scanned above. History cannot be rewritten (no force push).
  allow=()
  if [ -f ragfit/ci/leak-guard-allow-commits ]; then
    mapfile -t allow < <(grep -E '^[0-9a-f]{40}$' ragfit/ci/leak-guard-allow-commits || true)
  fi
  msgs=""
  while read -r c; do
    skip=0; for a in "${allow[@]}"; do [ "$c" = "$a" ] && skip=1; done
    [ "$skip" = 1 ] && continue
    msgs+=$(git log -1 --format='%an <%ae>%n%B' "$c")$'\n'
  done < <(git rev-list "${base}"..HEAD)
  scan "commit messages ${base}..HEAD" <<<"$msgs"
else
  echo "note: no upstream tag with merge base (shallow clone?), diff/commit-message scan skipped"
fi

[ "$fail" = 0 ] && echo "leak-guard: clean" || { echo "leak-guard: FAILED"; exit 1; }
