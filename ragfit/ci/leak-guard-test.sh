#!/usr/bin/env bash
# Tests for ragfit/ci/leak-guard.sh: allowed constructs are neutralized, never skip the whole line.
# Runs the real scan path (neutralize -> grep -n) via `leak-guard.sh --stdin`.
set -euo pipefail
g="$(git rev-parse --show-toplevel)/ragfit/ci/leak-guard.sh"
rc=0
pass() { printf '%s\n' "$1" | "$g" --stdin >/dev/null || { echo "FAIL (flagged, expected pass): $1"; rc=1; }; }
flag() { ! printf '%s\n' "$1" | "$g" --stdin >/dev/null || { echo "FAIL (passed, expected flag): $1"; rc=1; }; }
flag '@alice at the start of a line'
flag 'img@sha256:x cc @alice'
flag 'see @sha256evil'
flag 'uses: a/b@v1 # @alice'
flag 'Jane <1+jane@users.noreply.github.com> cc @alice'
pass 'image: ghcr.io/erynoagroup/ragfit-plan@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
pass 'pinned by digest (@sha256) only'
pass 'ends with @sha256'
pass '      - uses: actions/checkout@v4'
pass 'Jane <1+jane@users.noreply.github.com>'
flag 'see @SHA256evil'
pass 'img@SHA256:abcdef'
flag 'img@Sha256:x host.internal'

# Full-script tests on a temporary git repo (base tag, then leaks in a file, commit message, path)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
run() { # $1: expected exit (0/1/err), $2: label, rest: env
  local want=$1 label=$2 out rc=0; shift 2
  out=$(cd "$tmp/r" && env "$@" ragfit/ci/leak-guard.sh 2>&1) || rc=$?
  case "$want" in
    0) [ "$rc" -eq 0 ] || { echo "FAIL ($label): expected exit 0, got $rc"; echo "$out"; rc_all=1; } ;;
    1) { [ "$rc" -eq 1 ] && grep -q 'LEAK in' <<<"$out"; } || { echo "FAIL ($label): expected LEAK exit 1, got $rc"; echo "$out"; rc_all=1; } ;;
    err) { [ "$rc" -ne 0 ] && grep -q 'ERROR scanning' <<<"$out"; } || { echo "FAIL ($label): expected ERROR, got $rc"; echo "$out"; rc_all=1; } ;;
  esac
}
fresh() {
  rm -rf "$tmp/r"; git init -q "$tmp/r"; mkdir -p "$tmp/r/ragfit/ci"
  cp "$g" "$tmp/r/ragfit/ci/leak-guard.sh"
  ( cd "$tmp/r" && git add -A && git -c user.name=T -c user.email=t@erynoa.com commit -qm base && git tag v0.0.1 )
}
commit() { ( cd "$tmp/r" && git add -A && git -c user.name=T -c user.email=t@erynoa.com commit -qm "$1" ); }
rc_all=0
fresh; mkdir -p "$tmp/r/docs"; echo 'clean img@sha256:abc' > "$tmp/r/docs/a.md"; commit 'docs: clean'
run 0 'clean repo'
run err 'invalid RAGFIT_LEAK_EXTRA' 'RAGFIT_LEAK_EXTRA=(['
fresh; mkdir -p "$tmp/r/docs"; printf 'x\n@alice first\n' > "$tmp/r/docs/a.md"; commit 'docs: file leak'
run 1 'leak in file (start of line)'
fresh; mkdir -p "$tmp/r/docs"; echo ok > "$tmp/r/docs/a.md"; commit 'docs: thanks @alice'
run 1 'leak in commit message'
fresh; mkdir -p "$tmp/r/docs/@alice"; echo ok > "$tmp/r/docs/@alice/a.md"; commit 'docs: path'
run 1 'leak in path'
fresh; mkdir -p "$tmp/r/src"; printf 'x\n+ cc @alice\n' > "$tmp/r/src/a.rb"; commit 'src: plus line'
run 1 'leak in added line starting with +'
[ "$rc_all" -eq 0 ] || rc=1
[ $rc -eq 0 ] && echo "leak-guard tests: OK"
exit $rc
