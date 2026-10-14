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
flag 'pinned by digest (@sha256) only'
flag 'ends with @sha256'
flag '- @sha256 / x'
flag '@sha256/x'
flag '@sha256.x'
pass 'img@sha256:abc'
pass 'img@SHA256:abc'
pass '      - uses: actions/checkout@v4'
pass 'Jane <1+jane@users.noreply.github.com>'
flag 'see @SHA256evil'
pass 'img@SHA256:abcdef'
flag 'img@Sha256:x host.internal'
# CSS at-rules: neutralized only in stylesheets, only the exact keyword
css_pass() { printf '%s\n' "$1" | "$g" --stdin-css >/dev/null || { echo "FAIL (css flagged, expected pass): $1"; rc=1; }; }
css_flag() { ! printf '%s\n' "$1" | "$g" --stdin-css >/dev/null || { echo "FAIL (css passed, expected flag): $1"; rc=1; }; }
css_pass '@media (max-width: 400px) {'
css_pass '@media screen and (max-width: 543px) {'
css_pass '  @supports (display: grid) {'
css_pass '@font-face { font-family: x; }'
css_pass '@import url("a.css");'
css_pass '@-webkit-keyframes spin {'
css_pass '@keyframes spin {'
css_pass '@layer base, components;'
css_pass '@container sidebar (min-width: 400px) {'
css_pass '@MEDIA print {'
css_flag '/* thanks @alice */'
css_flag '@media print { } /* cc @alice */'
css_flag '@mediaeval {'
css_flag '@media-team please check'
css_flag 'a { color: red; } host.internal'
flag '@media (max-width: 400px) {'
# Code files: at-sign identifiers neutralized in code position only; comments, strings, ERB text still checked
code_pass() { printf '%s\n' "$2" | "$g" --stdin-code "$1" >/dev/null || { echo "FAIL ($1 flagged, expected pass): $2"; rc=1; }; }
code_flag() { ! printf '%s\n' "$2" | "$g" --stdin-code "$1" >/dev/null || { echo "FAIL ($1 passed, expected flag): $2"; rc=1; }; }
code_pass ruby '      @prefix = prefix.to_s.strip'
code_pass ruby '    return if @registered'
code_pass ruby '  @@cache ||= {}'
code_pass ruby 'log "deleting #{@login}"'
code_pass ruby 'x = { a: @a, b: [@b] }'
code_flag ruby '# thanks @alice'
code_flag ruby '  @prefix = x # cc @alice'
code_flag ruby 'raise "ask @alice"'
code_flag ruby "msg = 'ping @alice'"
code_flag ruby '  @x = "10.1.2.3"'
code_pass js '@Component({ selector: "x" })'
code_pass js 'this.@x'
code_flag js '// cc @alice'
code_flag js 'f(); // cc @alice'
code_flag js '/* thanks @alice */'
code_flag js ' * @alice wrote this'
code_flag js 'const s = "ping @alice";'
code_pass erb '<%= @user.name %>'
code_pass erb '<% if @show %><p>x</p><% end %>'
code_pass erb '<%= render partial: "x", locals: { u: @user } %>'
code_flag erb '<%# thanks @alice %>'
code_flag erb '<p>cc @alice</p>'
code_flag erb '<p>cc @alice <%= @user.name %></p>'
code_flag erb '<%= @user.name %> ping @alice'
code_flag erb '<%= t("hi @alice") %>'

# Full-script tests on a temporary git repo (base tag, then leaks in a file, commit message, path)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
run() { # $1: expected exit (0/1/err), $2: label, rest: env
  local want=$1 label=$2 out rc=0; shift 2
  out=$(cd "$tmp/r" && env "$@" ragfit/ci/leak-guard.sh 2>&1) || rc=$?
  case "$want" in
    0) [ "$rc" -eq 0 ] || { echo "FAIL ($label): expected exit 0, got $rc"; echo "$out"; rc_all=1; } ;;
    1) { [ "$rc" -eq 1 ] && grep -qE 'LEAK in|ERROR no base' <<<"$out"; } || { echo "FAIL ($label): expected LEAK exit 1, got $rc"; echo "$out"; rc_all=1; } ;;
    2) { [ "$rc" -eq 2 ] && grep -q 'ERROR' <<<"$out"; } || { echo "FAIL ($label): expected exit 2, got $rc"; echo "$out"; rc_all=1; } ;;
    err) { [ "$rc" -ne 0 ] && grep -q 'ERROR scanning' <<<"$out"; } || { echo "FAIL ($label): expected ERROR, got $rc"; echo "$out"; rc_all=1; } ;;
  esac
}
fresh() {
  rm -rf "$tmp/r"; git init -q "$tmp/r"; mkdir -p "$tmp/r/ragfit/ci"
  cp "$g" "$tmp/r/ragfit/ci/leak-guard.sh"
  cp "$(dirname "$g")/leak-guard-code.pl" "$tmp/r/ragfit/ci/leak-guard-code.pl"
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
fresh; mkdir -p "$tmp/r/src"; printf 'x\n+ cc @alice\n' > "$tmp/r/src/a.txt"; commit 'src: plus line'
run 1 'leak in added line starting with +'
fresh; mkdir -p "$tmp/r/web"; printf '@media (max-width: 400px) {\n  a { padding: 0 4px; }\n}\n@supports (x: y) {}\n' > "$tmp/r/web/a.css"; commit 'web: css'
run 0 'css at-rules in added stylesheet lines'
fresh; mkdir -p "$tmp/r/web"; printf '@media print {}\n/* cc @alice */\n' > "$tmp/r/web/a.css"; commit 'web: css'
run 1 'mention in added stylesheet lines'
fresh; mkdir -p "$tmp/r/docs"; printf 'use @media queries\n' > "$tmp/r/docs/a.md"; commit 'docs: x'
run 1 'at-rule word outside stylesheets'
fresh; mkdir -p "$tmp/r/app"; printf 'def x\n  @prefix = 1\nend\n' > "$tmp/r/app/a.rb"; commit 'app: ruby'
run 0 'ruby instance variable in added code lines'
fresh; mkdir -p "$tmp/r/app"; printf 'def x\n  # thanks @alice\n  @prefix = 1\nend\n' > "$tmp/r/app/a.rb"; commit 'app: ruby'
run 1 'mention in a Ruby comment'
fresh; mkdir -p "$tmp/r/app/views"; printf '<%%= @user.name %%>\n<%%# x %%>\n' > "$tmp/r/app/views/a.html.erb"; commit 'app: erb'
run 0 'ERB instance variable in code position'
fresh; mkdir -p "$tmp/r/app/views"; printf '<p>cc @alice</p>\n<%%= @user.name %%>\n' > "$tmp/r/app/views/a.html.erb"; commit 'app: erb'
run 1 'mention in ERB text'
fresh; mkdir -p "$tmp/r/app/views"; printf '<%%#\n  thanks @alice\n%%>\n' > "$tmp/r/app/views/a.html.erb"; commit 'app: erb'
run 1 'mention in a multi-line ERB comment'
fresh; mkdir -p "$tmp/r/web"; printf 'f();\n/*\n  thanks @alice\n*/\n' > "$tmp/r/web/a.js"; commit 'web: js'
run 1 'mention in a multi-line JS block comment'
fresh; mkdir -p "$tmp/r/app"; printf 'x = "10.1.2.3"\n' > "$tmp/r/app/a.rb"; commit 'app: ruby'
run 1 'private IP in added code lines'
fresh; ( cd "$tmp/r" && git tag -d v0.0.1 >/dev/null )
run 0 'no base: scan skipped'
run 1 'no base with RAGFIT_LEAK_REQUIRE_BASE=true' 'RAGFIT_LEAK_REQUIRE_BASE=true'
allow_line() { printf '%s\n' "$1" > "$tmp/r/ragfit/ci/leak-guard-allow-commits"; commit 'ci: allowlist'; }
allow_head() { allow_line "$(cd "$tmp/r" && git rev-parse HEAD) reviewed, no private data"; }
fresh; mkdir -p "$tmp/r/docs"; echo ok > "$tmp/r/docs/a.md"; commit 'docs: thanks @alice'; allow_head
run 0 'allowlisted commit: message scan skipped'
fresh; mkdir -p "$tmp/r/docs"; echo 'cc @alice' > "$tmp/r/docs/a.md"; commit 'docs: thanks @alice'; allow_head
run 1 'allowlisted commit: file/diff still scanned'
fresh; allow_line 'garbage'
run 2 'allowlist: garbage line'
fresh; allow_line "$(cd "$tmp/r" && git rev-parse --short HEAD) reason"
run 2 'allowlist: short SHA'
fresh; mkdir -p "$tmp/r/docs"; echo ok > "$tmp/r/docs/a.md"; commit 'docs: x'; allow_line "$(cd "$tmp/r" && git rev-parse HEAD)"
run 2 'allowlist: missing reason'
fresh; allow_line '0123456789abcdef0123456789abcdef01234567 reason'
run 2 'allowlist: unknown SHA'
fresh; allow_line "$(cd "$tmp/r" && git rev-parse v0.0.1) reason"
run 2 'allowlist: SHA outside base..HEAD'
[ "$rc_all" -eq 0 ] || rc=1
[ $rc -eq 0 ] && echo "leak-guard tests: OK"
exit $rc
