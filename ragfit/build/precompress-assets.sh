#!/usr/bin/env bash
# Precompress static assets at image build time: writes <file>.br and <file>.gz next to every
# compressible file, so the server can send them without compressing per request.
# Usage: precompress-assets.sh <dir> (default: $APP_PATH/public/assets). Needs gzip and brotli.
# A variant is kept only if it is smaller than the original. Existing variants are rebuilt.
set -euo pipefail

dir="${1:-${APP_PATH:-/app}/public/assets}"
min_bytes="${PRECOMPRESS_MIN_BYTES:-256}"
jobs="${PRECOMPRESS_JOBS:-$(nproc 2>/dev/null || echo 2)}"

[ -d "$dir" ] || { echo "precompress-assets: no such directory: $dir" >&2; exit 1; }
for tool in gzip brotli; do
  command -v "$tool" > /dev/null || { echo "precompress-assets: $tool missing" >&2; exit 1; }
done

compress_one() {
  f="$1"
  size=$(stat -c %s "$f")
  gzip -9 -n -c "$f" > "$f.gz"
  brotli -q 11 -c "$f" > "$f.br"
  for v in "$f.gz" "$f.br"; do
    if [ "$(stat -c %s "$v")" -ge "$size" ]; then rm -f -- "$v"; else touch -r "$f" -- "$v"; fi
  done
}
export -f compress_one

# shellcheck disable=SC2016  # $1 expands in the child bash
find "$dir" -type f -size +"$((min_bytes - 1))"c \
  \( -iname '*.js' -o -iname '*.mjs' -o -iname '*.css' -o -iname '*.svg' -o -iname '*.json' \
     -o -iname '*.html' -o -iname '*.txt' -o -iname '*.xml' -o -iname '*.ttf' -o -iname '*.eot' \
     -o -iname '*.ico' -o -iname '*.wasm' -o -iname '*.map' \) -print0 \
  | xargs -0 -r -n 1 -P "$jobs" bash -c 'compress_one "$1"' _

echo "precompress-assets: $(find "$dir" -type f -name '*.br' | wc -l) .br, $(find "$dir" -type f -name '*.gz' | wc -l) .gz in $dir"
