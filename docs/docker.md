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
Only bind mounts make media available to the container. No host library is copied
into the image. The build context allows runtime source directories only.

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

To roll back, run the previously verified registry digest. Never overwrite source
media as a recovery step. Publishing containers does not change CLI VERSION or
create a versioned source release.
