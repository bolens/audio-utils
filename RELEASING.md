# Release playbook

Audio Utils publishes Semantic Versioning releases from signed `vX.Y.Z` tags.
`VERSION` is authoritative. Releases are currently maintainer-driven, so the
tag, archive contents, checksum, and GitHub release all require explicit review.

## Prepare and validate

Create `release/vX.Y.Z` from current `origin/main`, update `VERSION`, and add a
dated reader-facing `CHANGELOG.md` entry if the repository has adopted one.
Update affected help and indexed documentation. Test only with disposable media
fixtures—never a real library.

```sh
make check
make test-all
test "$(<VERSION)" = X.Y.Z
```

If optional codecs or platforms are unavailable, record those skips in the PR
instead of treating them as passes. Review the intended payload for source
files, license material, and the absence of fixtures, caches, and private data.

## Review and publish

Do not push directly to `main`. Open a pull request, require all checks, and
squash-merge. Confirm `main` CI on
the merge SHA. Create a signed annotated tag only on that SHA, then create the
GitHub release from the tag with concise user-facing notes and a SHA-256
checksum for every attached archive.

```sh
git tag -s vX.Y.Z <validated-sha> -m 'audio-utils X.Y.Z'
git push origin vX.Y.Z
gh release create vX.Y.Z --verify-tag --generate-notes
```

## Verify and recover

Download the public asset, verify its checksum, unpack it into a temporary
directory, and run representative read-only and conversion-fixture smoke tests.
Confirm `--help` and version output. Never move a published tag; correct public
failures with a new patch release. Before publication, delete only an
unpublished tag and retry from a corrected, fully validated commit.

Fleet policy: <https://github.com/bolens/.github/blob/main/RELEASING.md>.

## Source lint

The Source lint workflow checks maintained JavaScript and Python files selected by
[`.github/source-lint.json`](.github/source-lint.json) on every pull request
and push to `main`. Existing native checks remain part of the merge gate.
Use the [shared local reproduction instructions](https://github.com/bolens/.github/blob/7603518f305fb76f7bb1b9979f2692521f633b82/docs/source-lint.md)
with the same tooling revision pinned in
[the workflow](.github/workflows/source-lint.yml). Review exclusions when adding
source files; generated and imported files retain their native validation.
Require the new check to pass on the current PR head before merging.

## Container delivery

Docker PR checks build the runtime image and run `make test-docker`. Require
`Docker runtime` alongside existing checks. Main pushes publish the tested image
to GHCR with `latest` and full-commit tags. Verify the Publish GHCR job and pull
and smoke-test the published digest after merge. Roll back by digest as described
in [Docker](docs/docker.md). Container delivery does not bump VERSION or create a
source release tag. PR and scheduled jobs never publish packages.
