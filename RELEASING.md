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
