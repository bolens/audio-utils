# Release playbook

[Documentation](README.md)

Releases are GitHub releases backed by a signed annotated `vMAJOR.MINOR.PATCH` tag.
The repository `VERSION` and `mcp/npm/package{,-lock}.json` versions must match
the tag without its `v` prefix. The npm package remains private and is not
published separately.

## Prepare

1. Fetch `origin` and tags. Confirm the release branch is based on the current
   `origin/main`, the worktree is clean, and the target tag does not exist.
2. Choose the next [semantic version](https://semver.org/). Update all three
   version-bearing files together:

   - `VERSION`
   - `mcp/npm/package.json`
   - the root package entries in `mcp/npm/package-lock.json`

3. Run the release checks:

   ```bash
   make check
   make test
   make test-functional
   (cd mcp/npm && npm test && npm audit --omit=dev)
   actionlint
   make coverage
   ```

   `make check` includes immutable dependency enforcement: every external
   GitHub Action must use a full 40-character commit SHA. Keep the release tag
   in a trailing comment so Dependabot updates remain readable.

4. Commit the version and playbook updates, push the branch, and open a PR
   summarizing user-visible changes and validation.

## Merge

Watch required checks with `gh pr checks --watch`. Do not merge with failing or
pending checks. If CI needs a fix, commit it to the same branch and wait for the
replacement run. Squash-merge the PR and delete its branch. Direct pushes to
`main`, rebase merges, merge commits, and protection bypasses are disabled.
With a clean worktree, update the local branch from the merged result:

```bash
git fetch origin
git switch main
git merge --ff-only origin/main
```

## Publish

Use the authoritative GitHub checkout and a separately authorized product release.
Follow [the owning delivery playbook](../RELEASING.md) for remote and publication
authority; Gitea copies do not create duplicate tags or releases.

1. Confirm `main` is clean, contains the merged PR, passes the version
   consistency checks above, and still has no tag for the release version.
2. Create and verify a signed annotated tag at the exact validated merged
   `origin/main` commit, then push only that tag:

   ```bash
   version="$(<VERSION)"
   git tag -s "v${version}" origin/main -m "audio-utils ${version}"
   git verify-tag "v${version}"
   git push origin "refs/tags/v${version}"
   ```

3. Create the GitHub release from that existing remote tag:

   ```bash
   gh release create "v${version}" --verify-tag --generate-notes
   ```

   Use concise notes grouped by user-visible features, fixes,
   security/dependency changes, and validation.
4. Verify the release is published (not draft or prerelease), its tag and target
   commit are correct, and the tag is visible after `git fetch --tags`.

Never move or overwrite a published release tag. Correct a bad release with a
new patch version.
