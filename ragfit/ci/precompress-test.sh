#!/usr/bin/env bash
# Checks ragfit/build/precompress-assets.sh on a fixture: variants exist for compressible files,
# decompress byte-identical, keep the source mtime, and are skipped for small, binary or
# incompressible files. A second run must give the same result.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
script=ragfit/build/precompress-assets.sh
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/frontend"

for i in $(seq 1 2000); do echo "export const value$i = 'ragfit precompress fixture $i';"; done > "$t/frontend/main-ABC.js"
for i in $(seq 1 500); do echo ".c$i{color:#123456;margin:${i}px}"; done > "$t/frontend/styles-ABC.css"
echo 'x' > "$t/frontend/tiny.js"                                  # below 256 bytes
head -c 4096 /dev/urandom > "$t/frontend/random.js"              # incompressible
head -c 4096 /dev/urandom > "$t/frontend/image.png"              # not a text type
touch -d '2020-01-01 00:00:00' "$t/frontend/main-ABC.js"

fail() { echo "precompress-test: FAILED: $*" >&2; exit 1; }
check() {
  for f in main-ABC.js styles-ABC.css; do
    p="$t/frontend/$f"
    [ -f "$p.br" ] && [ -f "$p.gz" ] || fail "$f: missing variant"
    cmp -s "$p" <(brotli -d -c "$p.br") || fail "$f.br differs after decompression"
    cmp -s "$p" <(gzip -d -c "$p.gz") || fail "$f.gz differs after decompression"
    [ "$(stat -c %s "$p.br")" -lt "$(stat -c %s "$p")" ] || fail "$f.br not smaller"
  done
  [ "$(stat -c %Y "$t/frontend/main-ABC.js.br")" = "$(stat -c %Y "$t/frontend/main-ABC.js")" ] || fail "mtime not kept"
  for f in tiny.js random.js image.png; do
    [ ! -e "$t/frontend/$f.br" ] && [ ! -e "$t/frontend/$f.gz" ] || fail "$f: unexpected variant"
  done
}

bash "$script" "$t"; check
first=$(cd "$t" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
bash "$script" "$t"; check
[ "$first" = "$(cd "$t" && find . -type f -print0 | sort -z | xargs -0 sha256sum)" ] || fail "second run changed files"
if bash "$script" "$t/missing" 2>/dev/null; then fail "missing directory accepted"; fi
echo "precompress-test: clean"
