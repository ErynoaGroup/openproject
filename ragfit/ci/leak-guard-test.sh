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
[ $rc -eq 0 ] && echo "leak-guard tests: OK"
exit $rc
