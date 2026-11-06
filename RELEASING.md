# Release playbook

[Documentation](docs/README.md)

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

The native Woodpecker core checks maintained JavaScript and Python files selected
by [`.github/source-lint.json`](.github/source-lint.json), using
[`scripts/ci/check-fleet.sh`](scripts/ci/check-fleet.sh) and the same pinned fleet
tooling as [the hosted Source lint fallback](.github/workflows/source-lint.yml).
The hosted check runs whenever either `WOODPECKER_LINUX_CI` or
`WOODPECKER_PUBLISHING` is not `true`. After the paired cutover is accepted,
require all six native PR checks plus `Development environment` and `Docker runtime`
on the current head; do not require an intentionally skipped fallback.

Use the [shared local reproduction instructions](https://github.com/bolens/.github/blob/7603518f305fb76f7bb1b9979f2692521f633b82/docs/source-lint.md)
with the same pinned tooling revision. Review exclusions when adding source files;
generated and imported files retain their native validation. See the
[cutover contract](docs/docker.md) for profile, flag, and protection ordering.

## Container delivery

Docker PR checks build the runtime image and run `make test-docker`. Keep
`Docker runtime` required alongside native checks and the retained development
environment gates, including macOS and actual Docker execution.

With `WOODPECKER_PUBLISHING=true`, the broker policy and full Woodpecker profile
must be enabled together. Canonical main pushes build an immutable candidate in
Woodpecker. The retained hosted `Accept exact Woodpecker image` bridge runs full
runtime acceptance, then promotes that exact digest to the commit and `latest`
tags without rebuilding. Require the native publisher and bridge to succeed and
verify the candidate, commit, and `latest` tags resolve to the accepted digest.
With publication disabled, the hosted `Publish GHCR` job remains the fallback.

Follow [Docker](docs/docker.md) for the ordered cutover and rollback: drain native
and hosted publishers, select the validation-only profile, then clear the
publication flag. Roll runtime deployments back by verified digest. Container
delivery does not bump VERSION or create a source release tag. PR and scheduled
jobs never publish packages; product releases remain separately authorized signed
tag and GitHub-release operations above.

## CI toolchain delivery

The native Linux development gate consumes an immutable public GHCR manifest and
runs the current checkout through the image's input-key checker with networking
disabled. The [offline CI environment guide](docs/offline-ci-environment.md) owns
preparation, content verification, full-gate/fault admission and successor updates.
Keep all six native checks, `Development environment`, `Docker runtime` and the
byte-identical generated validation profile required through normal protected delivery.

For each successor: admit content, all six gate cases and both faults; publish
only immutable `ci-env-KEY`; verify the public manifest digest and anonymous pull;
then review the source/input and consumer-digest change together. Credentials
belong only to the trusted push, never the image or ordinary PR validation.

CI toolchain delivery leaves `VERSION`, product tags, runtime aliases and the
signed GitHub-release procedure above unchanged. Roll back through a protected
change to a previously accepted digest with compatible dependency inputs. A key
mismatch fails closed without an online fallback.
