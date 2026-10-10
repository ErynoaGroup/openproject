# Upstream sync

Upstream: `https://github.com/opf/openproject` (GitHub releases `vX.Y.Z`, no pre-releases).
The repo is ~3 GB; manual work should use `--filter=blob:none` or fetch single tags.

## Automatic (daily)

1. Query the highest non-draft, non-prerelease release `vX.Y.Z`.
2. If `main` already contains it, or branch `sync/vX.Y.Z` exists: done.
3. Otherwise push the tag, create **new** branch `sync/vX.Y.Z` = `main` + merge of the
   tag (no force-push anywhere), open PR `sync/vX.Y.Z -> main` labeled `upstream-sync`.
4. If the merge touches `db/migrate` or `modules/*/db/migrate*`, the PR also gets
   `schema-migration`. Rails migrations are forward-only: take a `pg_dump` and a copy of
   the attachments volume before rollout.
5. **Never auto-merged.** A human reviews the release notes, merges with a merge commit,
   the merge triggers `erynoa-build.yml`.
6. After merging, disable any **new** upstream workflow file.

Note: PRs opened with `GITHUB_TOKEN` need the org/repo setting
"Allow GitHub Actions to create and approve pull requests".

## Manual fallback

```sh
git remote add upstream https://github.com/opf/openproject.git
git fetch upstream tag vX.Y.Z --no-tags
git switch -c sync/vX.Y.Z origin/main
git merge --no-ff -m "sync: upstream vX.Y.Z" vX.Y.Z
git push origin vX.Y.Z sync/vX.Y.Z
gh pr create -B main -H sync/vX.Y.Z -t "sync: upstream vX.Y.Z" -l upstream-sync
```
