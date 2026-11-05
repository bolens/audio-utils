# Docker

[Documentation](README.md)

Build from the repository root:

```sh
docker build --pull -t audio-utils:local .
docker run --rm audio-utils:local --help
make test-docker
```

The image uses digest-pinned Debian 13 and distribution runtime packages.
Package versions resolve at build time. Rebuild with `--pull --no-cache` to pick
up package security updates, and review base digest updates separately.
The published image targets Linux amd64. Other Linux architectures may build
from this Dockerfile, but are not validated by the current CI.

## Published images

Main pushes build, test and publish `ghcr.io/bolens/audio-utils:latest` and
`ghcr.io/bolens/audio-utils:sha-<full-commit>`. PRs and the weekly scheduled check
build and test only. The publication job tests the exact local image it pushes.
No host tools, release tags or personal access tokens are installed by the image.
Use a registry digest for deployment pinning because tags can move.

```sh
docker pull ghcr.io/bolens/audio-utils:latest
```

GHCR package visibility is managed separately from repository visibility. If the
package is private, authenticate with an account that can read it before pulling.
The workflow uses its repository-scoped `GITHUB_TOKEN` with `packages: write`.
See [GitHub's registry guide](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).

## Files and ownership

The image defaults to UID/GID 10001. On Linux, use your UID/GID so new files belong
to you. Create writable output directories before mounting them. Container paths,
including paths in configuration and manifests, must refer to the mounted paths.
Supply media through explicit mounts. The build context allows runtime source
directories only.

Audio converters write verified outputs beside their input. Mount a disposable
working copy read-write for conversion. Existing audio flags retain their meaning:
`-n` previews, normal conversion writes, and deletion still requires the tool's
explicit deletion flag. A read-only mount works for audits, but cannot receive
sibling conversion outputs.

```sh
mkdir -p work
docker run --rm --network=none --read-only --tmpfs /tmp \
  --cap-drop=ALL --security-opt=no-new-privileges \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD/work,dst=/data" \
  audio-utils:local wav-to-flac -n -j 1 /data
```

Remove `-n` to convert the working copy. Tool names match their directory names,
such as `wav-to-flac`, `flac-verify` and `audio-compare`. Arguments are passed
unchanged. The image entrypoint accepts installed tool names only.

Included extras: Chromaprint, Musepack, BPM, ReplayGain, SoX, MediaInfo,
cdparanoia, dvdbackup, minisign, par2, ICU tools, jq and curl. Monkey's Audio
encoding, TAK encoding/Wine, keyfinder-cli, MakeMKV and libdvdcss are not bundled.
Their dependent features still require those tools in a derived image. See the
[requirements matrix](requirements.md). Optical-drive access needs explicitly
mapped devices and group permissions. DRM/decryption credentials are not included.
Network enrichment requires an explicit network-enabled run and existing opt-in
flags. The sample command has networking disabled.

The Bash stdio MCP server is included and can be selected with
`--entrypoint /opt/audio-utils/mcp/server.sh`; use `-i` without `-t`. Its existing
execution/configuration policy still applies. The optional Node HTTP gateway is
not bundled and no port is exposed.

## Runtime state and validation

HOME and XDG directories default under writable `/tmp`, so an arbitrary numeric
UID works with a read-only root filesystem. State and logs disappear with the
container. For persistent state, mount a writable directory and set
`XDG_STATE_HOME` to that path. Mount configuration read-only and set
`XDG_CONFIG_HOME` when needed. Filesystem permissions still apply to all mounts.

`make docker-build` builds only. `make test-docker` also runs real disposable
conversions, source/output comparisons, unusual filenames, ownership checks,
non-root defaults, dry runs and failures with a read-only root and no network.
Host Python 3.11+ is needed for tests. Rootless Podman can run the same checks via
`make test-docker CONTAINER_ENGINE=podman`. Existing native suites remain separate.

For a remote Docker 26+ daemon, the optional volume transport transfers only the
same disposable fixtures through `docker cp`, without daemon-host bind paths:

```sh
python3 scripts/test-docker.py --image audio-utils:local --transport volume
```

It uses private named volumes, a read-only input mount, a writable output mount,
and the same numeric UID/GID and acceptance checks. Exported input snapshots must
preserve every path, kind, permission and file byte before outputs are accepted.
Output snapshots verify daemon-exported numeric UID/GID and reflect deletions.
Local fixture copies belong to the controller user; owner evidence is retained
across runs so a wrong container-created UID cannot be relabeled by a later seed. Each volume holds a seeded `data` child
directory; subpath mounts preserve its UID/GID instead of reusing the daemon-owned
volume root. Test containers and volumes are removed
on success and failure; cleanup failure fails the run. The default bind transport
is unchanged. Volume transport is tested with Docker; Podman keeps its existing
bind-mode validation. CI must use an isolated build/runtime engine rather than
exposing a general host Docker socket to repository jobs.

To roll back, run the previously verified registry digest. Never overwrite source
media as a recovery step. Publishing containers does not change CLI VERSION or
create a versioned source release.

## Woodpecker publication cutover

The staged `.woodpecker/publishing.yml` selects only canonical GitHub protected-main
pushes. The server broker must approve the event and the canonical repository
variable `WOODPECKER_PUBLISHING` must explicitly enable delivery. Until native
checks, broker policy and the hosted bridge pass acceptance, keep that flag off
and retain the legacy GitHub Docker owner. PR, manual, cron and Gitea events do not
select publisher steps or credentials. Gitea mirrors retain validation only.
Coordinate the flag and publishing-owner transition before merging this active
configuration; a missing broker credential fails closed.

The pinned socket-free Kaniko plugin builds one immutable candidate using only
image-filtered `ghcr_username` and `ghcr_password`. A protected-ref broker lease
`github_publish_lease` provides a short-lived App token in memory for the exact
source. The native helper verifies archive and registry config/source/platform,
then dispatches the thin hosted Docker bridge and exits with a pending receipt.

That bridge requires the approved App actor, exact current-main commit and native
repo 11 pipeline, and all seven successful native workflow contexts from the
configured `WOODPECKER_STATUS_CREATOR_ID`. The context prefix defaults to
`ci/woodpecker`. It pulls the candidate digest, checks its immutable identity,
and runs the complete existing runtime fixture suite without rebuilding. It then
copies the same digest to `sha-<full-commit>` and `latest`, rechecking protected
main immediately before each write and refusing a conflicting immutable tag.
The hosted Docker runtime remains an explicit migration exception; no registry
promotion has been performed to validate this migration.

Before reverting the publishing flag, stop new publishing triggers and cancel or
drain every active native candidate and hosted runtime/promotion bridge. Confirm
that queued dispatches cannot still write aliases, then clear the flag and restore
the prior workflow/check ownership together. This prevents an in-flight bridge
from publishing after the legacy publisher resumes. Preserve immutable tags and
inspect pending receipts before retrying. Failed validation PR checks do not need
publication credentials or a flag change.

## Retiring duplicate portable Linux validation

Both repository variables `WOODPECKER_LINUX_CI=true` and
`WOODPECKER_PUBLISHING=true` are required to retire the duplicate portable Linux
jobs. Keep `WOODPECKER_LINUX_CI` absent or false until exact PR and merged-main
native checks pass, the broker and publishing owner are accepted, and required
checks migrate to the tested native contexts. The publishing flag follows its
separate coordinated owner cutover; it can be enabled first while duplicate Linux
validation remains active. Publication rollback restores these hosted checks when its flag
is cleared; cancel or drain active publishers before changing that owner flag.
Native macOS, Linux Nix/devenv validation while its native parity remains unproven,
actual Docker/runtime/devcontainer validation, and metadata/update automation
remain hosted. The validation flag does not authorize credentials or publication.

Before retiring the legacy weekly CI schedule, trigger and verify the actual
native weekly cron: `weekly-full-validation`, Monday 11:17 UTC (`17 11 * * 1`),
branch `main`. All six native validation lanes must pass; cron never selects the
publisher. The hosted Docker Monday 12:43 UTC schedule remains. Preserve required
Docker/development-environment checks while migrating portable CI/source checks.
