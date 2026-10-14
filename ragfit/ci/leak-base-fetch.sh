#!/usr/bin/env bash
# Makes a shallow CI checkout usable for the leak-guard diff and commit-message scan: fetches the upstream
# tag vX.Y.Z of lib/open_project/version.rb (depth 1) and deepens the checked-out commit until it reaches
# that tag (merge base). Prints the tag on stdout; fails if the merge base is not reached.
# Usage: ragfit/ci/leak-base-fetch.sh [max-deepen-steps]   (50 commits per step, default 40)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
f=lib/open_project/version.rb
v="$(sed -nE 's/^ *MAJOR = ([0-9]+).*/\1/p' $f).$(sed -nE 's/^ *MINOR = ([0-9]+).*/\1/p' $f).$(sed -nE 's/^ *PATCH = ([0-9]+).*/\1/p' $f)"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "leak-base-fetch: cannot read version from $f" >&2; exit 1; }
tag="v${v}"
git rev-parse -q --verify "refs/tags/${tag}^{commit}" >/dev/null ||
  git fetch -q --no-tags --depth=1 origin "refs/tags/${tag}:refs/tags/${tag}" >&2
head=$(git rev-parse HEAD)
steps=0
until git merge-base "$tag" HEAD >/dev/null 2>&1; do
  [ "$(git rev-parse --is-shallow-repository)" = true ] || break
  [ "$steps" -lt "${1:-40}" ] || break
  git fetch -q --no-tags --deepen=50 origin "$head" >&2
  steps=$((steps+1))
done
git merge-base "$tag" HEAD >/dev/null 2>&1 || { echo "leak-base-fetch: no merge base with $tag after $steps deepen steps" >&2; exit 1; }
echo "leak-base-fetch: $tag, merge base $(git merge-base "$tag" HEAD), $(git rev-list --count "$tag"..HEAD) commits since" >&2
echo "$tag"
