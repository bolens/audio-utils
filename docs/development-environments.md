# Development environments

[Documentation](README.md)

Install [Nix and devenv](https://devenv.sh/getting-started/), then run from this checkout:

```sh
devenv shell
repo-check
# Or run the same portable gate non-interactively:
devenv test
```

The shell supplies Bash, GNU utilities, Python, Ruff, Node, ShellCheck, FFmpeg, FLAC, and preservation tools. On Linux, `repo-check` runs `make check`, Ruff on the Python adapter and its tests, the adapter tests, locked MCP dependency installation and tests, and `make test-all JOBS=4`. Override `JOBS` to change test concurrency. npm installation requires network access; media tests use disposable fixtures and report optional codec skips. Native macOS runs lint and adapter tests only. See [requirements.md](requirements.md) and [../tests/README.md](../tests/README.md) for preservation contracts.

Commit `devenv.lock` with deliberate input updates. Local state and `devenv.local.nix` / `devenv.local.yaml` overrides are ignored. Existing Nix cache settings are used without changing daemon trust.

## Docker and Podman

Build and load the development image, then run a command with a local engine:

```sh
python3 scripts/development-container.py build podman
python3 scripts/development-container.py run podman -- bash scripts/check-development.sh
# Substitute docker for podman to use Docker.
```

Omit the command for an interactive Bash shell. The helper mounts the checkout at `/workspace`, runs with the caller's UID/GID, and uses Podman's keep-id mapping. It forwards arguments and exit status without constructing a shell command. These mounts require a local engine with access to the checkout path; remote Docker daemons need their own source transfer. Paths containing commas are rejected because they cannot be represented by this mount syntax.

The image contains tools, not checkout files. Build archives live under `.devenv/containers/` and are never uploaded by the helper. Existing production images and Compose stacks are separate from this development image.

## Remote Docker validation

When a Docker daemon cannot mount the local checkout, use the optional tracked-source
adapter after loading the development image into that daemon:

```sh
bash scripts/check-development-container.sh localhost/audio-utils-dev:latest \
  bash -c 'make check && make test && make coverage'
```

This requires local Git, Python and GNU tar. `CONTAINER_ENGINE` selects the Docker
CLI executable; its existing remote-daemon configuration is respected. The adapter
copies current tracked files into a disposable container, including tracked edits.
It excludes ignored and untracked files, `.git` credentials and local dependency
directories. Keep secrets out of tracked files. The copy and parent directories
belong to UID/GID 10001. Execution uses that unprivileged user, drops all
capabilities, prevents privilege escalation and disables networking. It does not
mount the checkout or Docker socket. Commands that install dependencies need a
separately prepared image. The container is removed after success or failure and
its command exit status is returned. The local bind-mount adapter remains useful
for interactive development and the full network-dependent `repo-check` gate.

## Apple container

[Apple container](https://github.com/apple/container) requires a supported Apple-silicon Mac. Start its runtime according to Apple's installation guide. With a Linux Nix builder configured:

```sh
python3 scripts/development-container.py build apple
python3 scripts/development-container.py run apple -- bash scripts/check-development.sh
```

The helper exports an OCI archive and uses `container image load`. Native ARM Macs target `aarch64-linux`; x86 Linux builds target `x86_64-linux`. [Building Linux images from macOS requires a Linux builder](https://devenv.sh/containers/). This workflow does not assume Apple container implements Docker Compose or Docker's daemon API.

Apple execution is not verified by Linux tests. The product targets GNU/Linux. Native macOS checks exercise the development toolset; use a Linux container for Linux runtime behavior. The development image does not provide the Monkey's Audio encoder, Musepack encoder/decoder, keyfinder-cli, or SoX DFF handler; those optional cases report skips. Optional codec and hardware cases retain explicit skip reporting; no proprietary codecs are installed by this profile. Tests use disposable generated media and retain sources.

## Native Linux CI parity

The existing Woodpecker `woodpecker` workflow also runs the locked `devenv test`
gate in a pinned Nix container, without a Docker socket, host mounts or publisher
credentials. Nix builds use one job and two cores; application tests use bounded workers.
The generated validation-only profile includes the same gate and check identity.

Keep `WOODPECKER_NIX_CI` absent or false until the exact PR and genuine merged-main
native runs pass. Only then may the operator set it to literal `true` to skip the
duplicate hosted Linux `devenv test` step. Clearing the flag restores that check.
The flag does not skip macOS, actual Docker development/runtime/editor-image
validation, or OIDC signing, and does not authorize publishing. Source review and
workflow parsing do not prove cold-store Nix execution or native parity.

### Offline CI toolchain consumer

The native Linux gate uses a digest-pinned dependency image and runs the current
checkout with a complete input-key check, fresh private COW/HOME/XDG state and
networking disabled. Its verified source packs and npm content provide the
required offline dependencies. A mismatch requires a reviewed successor image;
the job never falls back to host caches or online dependency fetches.

Ordinary local `devenv` setup above is unchanged. The
[offline environment guide](offline-ci-environment.md) owns preparation, admission,
publication and rollback. Preserve all six native identities, validation mirrors,
macOS, real Docker export and devcontainer checks. Rollback pairs a previously
accepted image with compatible dependency inputs.
