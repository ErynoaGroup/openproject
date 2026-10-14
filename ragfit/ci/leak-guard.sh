#!/usr/bin/env bash
# Leak guard for this PUBLIC fork: no hostnames, tailnet data, private IPs, internal names or @-mentions
# in our own files or in our changes compared to upstream. Upstream files are not scanned (they contain
# upstream e-mail addresses and code annotations), only what we add.
# Usage: ragfit/ci/leak-guard.sh [upstream-ref]   (default: newest vX.Y.Z tag in the repo)
# RAGFIT_LEAK_REQUIRE_BASE=true: fail instead of skipping the diff/commit-message scan when no base is
# available (CI; a shallow checkout is made usable by ragfit/ci/leak-base-fetch.sh).
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
# Any digest marker left after neutralize() (i.e. not followed by ':') is a hit, whatever follows it
P_DIGEST='@sha256'
PATTERN="(${P_TAILNET})|(${P_CGNAT})|(${P_PRIVIP})|(${P_MENTION})|(${P_DIGEST})|(${P_INTERNAL})"
# Code (patches and added lines of code files): Ruby instance variables (@provider), decorators and the like
# look like mentions → no mention check there
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
# Stylesheets only: CSS at-rules (@media, @supports, @font-face, @-webkit-keyframes, ...) are not mentions.
# Only the exact at-rule keyword is neutralized; anything else after '@' is still checked.
CSS_AT_RULES='media|supports|font-face|import|keyframes|layer|container|charset|namespace|page|property|counter-style|font-feature-values|font-palette-values|scope|starting-style|view-transition|document|use|forward|include|mixin|extend|if|else|each|for|while|function|return|warn|error|debug|at-root|content'
neutralize_css() {
  sed -E -e "s/(^|[^A-Za-z0-9_@-])@(-[a-z]+-)?(${CSS_AT_RULES})([^A-Za-z0-9_-]|$)/\1_atrule_\2\3\4/gI"
}

fail=0
# Runs in the PARENT shell (never `... | scan`), so fail=1 survives. Fails closed: grep exit 1 means
# no hits, anything >= 2 (e.g. an invalid RAGFIT_LEAK_EXTRA pattern) fails the guard.
scan() { # stdin: text, $1: label, $2: optional pattern, $3: "css" to neutralize CSS at-rules
  local hits rc=0 css=cat
  [ "${3:-}" = css ] && css=neutralize_css
  hits=$(neutralize | $css | grep -nEi -e "${2:-$PATTERN}") || rc=$?
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
if [ "${1:-}" = --stdin-css ]; then scan stdin "$PATTERN" css; [ "$fail" = 0 ] || exit 1; exit 0; fi
# pathspecs: code files get PATTERN_CODE, stylesheets the full pattern with CSS at-rules neutralized
CODE_SPEC=(':(glob)**/*.rb' ':(glob)**/*.rake' ':(glob)**/*.erb' ':(glob)**/*.js' ':(glob)**/*.mjs' ':(glob)**/*.ts' ':(glob)**/Gemfile' ':(glob)**/*.gemspec')
CSS_SPEC=(':(glob)**/*.css' ':(glob)**/*.scss' ':(glob)**/*.sass')
EXCL_SPEC=(':!ragfit/ci/leak-guard.sh' ':!ragfit/ci/leak-guard-test.sh' ':!ragfit/patches')

own_files=()
for p in "${OWN[@]}"; do
  mapfile -t -O "${#own_files[@]}" own_files < <(git ls-files -- "$p" 2>/dev/null)
done
for f in "${own_files[@]}"; do
  case "$f" in ragfit/ci/leak-guard.sh|ragfit/ci/leak-guard-test.sh) continue ;; esac   # patterns / test fixtures
  [ -f "$f" ] || { echo "missing in checkout (sparse?): $f" >&2; fail=1; continue; }
  case "$f" in
    *.patch) scan "$f" "$PATTERN_CODE" < "$f" ;;
    *.css|*.scss|*.sass) scan "$f" "$PATTERN" css < "$f" ;;
    *) scan "$f" < "$f" ;;
  esac
done
scan "own file paths" < <(printf '%s\n' "${own_files[@]}" | paths)

base="${1:-$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)}"
if [ -n "$base" ] && git rev-parse -q --verify "${base}^{commit}" >/dev/null && git merge-base "$base" HEAD >/dev/null 2>&1; then
  # strip the diff "+" so a mention at the start of an added line still matches
  echo "leak-guard: diff and commit-message scan against ${base} (merge base $(git merge-base "$base" HEAD), $(git rev-list --count "${base}"..HEAD) commits)"
  other=(); for s in "${CODE_SPEC[@]}" "${CSS_SPEC[@]}"; do other+=(":(exclude,glob)${s#:(glob)}"); done
  added=$(git diff "${base}"...HEAD -- . "${EXCL_SPEC[@]}" "${other[@]}" | added_lines)
  scan "diff ${base}...HEAD (added lines)" <<<"$added"
  added=$(git diff "${base}"...HEAD -- "${CODE_SPEC[@]}" "${EXCL_SPEC[@]}" | added_lines)
  scan "diff ${base}...HEAD (added code lines)" "$PATTERN_CODE" <<<"$added"
  added=$(git diff "${base}"...HEAD -- "${CSS_SPEC[@]}" "${EXCL_SPEC[@]}" | added_lines)
  scan "diff ${base}...HEAD (added stylesheet lines)" "$PATTERN" css <<<"$added"
  added=$(git diff "${base}"...HEAD -- ragfit/patches | added_lines)
  scan "patches diff ${base}...HEAD" "$PATTERN_CODE" <<<"$added"
  changed=$(git diff --name-only "${base}"...HEAD)
  scan "changed paths ${base}...HEAD" < <(printf '%s\n' "$changed" | paths)
  # Commits listed in leak-guard-allow-commits skip ONLY the message scan; their files, diff and
  # paths are still scanned above. History cannot be rewritten (no force push).
  # Format: '#' comments, blank lines, or '<full 40-hex SHA> <reason>'. Anything else, an unknown
  # commit or a commit outside ${base}..HEAD exits 2.
  revs=$(git rev-list "${base}"..HEAD)
  declare -A allow=()
  allow_file=ragfit/ci/leak-guard-allow-commits
  if [ -f "$allow_file" ]; then
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n+1))
      case "$line" in ''|'#'*) continue ;; esac
      if ! [[ "$line" =~ ^([0-9a-f]{40})\ +[^\ ].*$ ]]; then
        echo "leak-guard: ERROR $allow_file:$n: expected '<40-hex SHA> <reason>'" >&2; exit 2
      fi
      sha="${BASH_REMATCH[1]}"
      if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
        echo "leak-guard: ERROR $allow_file:$n: unknown commit $sha" >&2; exit 2
      fi
      if ! grep -qx "$sha" <<<"$revs"; then
        echo "leak-guard: ERROR $allow_file:$n: $sha is not in ${base}..HEAD" >&2; exit 2
      fi
      allow[$sha]=1
    done < "$allow_file"
  fi
  msgs=""
  while read -r c; do
    [ -n "$c" ] || continue
    [ -n "${allow[$c]:-}" ] && continue
    msgs+=$(git log -1 --format='%an <%ae>%n%B' "$c")$'\n'
  done <<<"$revs"
  scan "commit messages ${base}..HEAD" <<<"$msgs"
elif [ "${RAGFIT_LEAK_REQUIRE_BASE:-}" = true ]; then
  echo "leak-guard: ERROR no base '${base}' with a merge base in this checkout (shallow? run ragfit/ci/leak-base-fetch.sh) – failing" >&2
  fail=1
else
  echo "note: no upstream tag with merge base (shallow clone?), diff/commit-message scan skipped"
fi

[ "$fail" = 0 ] && echo "leak-guard: clean" || { echo "leak-guard: FAILED"; exit 1; }
