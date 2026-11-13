# Offline CI environment

The native Linux development gate consumes an immutable public dependency image
and executes the current checkout through its bound checker. Application and test
code run from that checkout; an old executable application checkout is not baked
into the image. Ordinary local development setup is unchanged.

## Inputs and preparation

`ci/offline-environment/contract.json` binds the base digest, platform, pinned Nix
and devenv versions, environment locks, npm declarations and reviewed recipe/gate
dependency declarations. Conservative mixed installer/hook/fixture declarations
are keyed as complete files. Ordinary product and unit/functional test bodies
are excluded and always come from current source. Consumer workflow files are
excluded to avoid a digest/key cycle. Unknown imports, overrides, symlinks and
untracked dependency declarations fail closed.

Prepare only a clean committed public allowlist with the repository helper:

```sh
python3 scripts/ci/offline_environment.py context --output DIR
```

`DIR` must be a new owned destination. Two guarded RUNs use private builder COW state, 2 CPUs, 4 GiB memory and no swap.
The stable first phase realizes public dependencies. The second has OS networking
disabled: it materializes the revision/NAR-pinned CLI root, exports only declared
Git tree/blob closures and writes checked metadata. It does not run
`nix flake archive`, evaluate dependency outputs or realize missing dependencies.
Late checker changes can reuse a verified first layer; lock or bootstrap changes
invalidate it. No host store/cache, credentials or application checkout is copied.

## Closed offline source and npm state

SQLite revision mappings require their Git objects. v3 uses `tarball-cache`; v4
uses pack-only `tarball-cache-v2`. Retain only self-contained packs of the mapped
reachable tree/blob objects, without commits, refs, hooks, copied configuration,
alternates or unreachable objects. Per-cache limits are 200,000 objects, 512 MiB
uncompressed object bytes and a 512 MiB pack. Verify hashes, exact reachability,
types, sizes and census when preparing and hydrating a fresh private bare SHA-1
repository with empty templates and strict `index-pack`.

Known locked NARs, including the CLI root's explicit pin, are verified from raw
Git content without checkout/archive attribute transformations. Executable modes
and symlink text are preserved. Canonical entries without NARs remain explicit;
no pins or lock changes are fabricated. Missing trees, corrupt packs, extra
objects or NAR mismatches fail before tests. Registered Nix content is verified
independently, including derivations and source closures.

Each execution gets fresh HOME/XDG and random devenv state, a private COW Nix
store/database, and forced offline npm with verified content. Distinct empty
mode-0600 user/global npmrc files live under a mode-0700 private parent. The clean
environment excludes inherited test selectors, make dry-run controls, npmrc and
`NIX_CACHE_HOME`. Offline paths disable the global flake registry. Nix `--offline`
alone is not a network boundary: step-level `network_mode: none` is mandatory.

The checker reads complete, bounded link, address and route dumps from its own
network namespace. It accepts loopback and an inert IPIP fallback only when its
link type, down state, zero endpoints and lack of addresses or usable routes are
verified. Network and system administration capabilities are forbidden. An
interface name alone is insufficient, and an incomplete census fails closed.
Preparation and runtime share this policy; runtime also requires the disposable
Docker marker and rejects a mounted Nix store or database. Refusals use fixed
guard classes without printing arbitrary exception text or network addresses.

## Runtime admission and publication

Before publishing each generation, bind source, key and actual image identity
through the independent content/privacy audit, six-case gate observer and two
fault cases. Require terminal owned-container lifecycles. An image build,
manifest check, warm shell or successful subset is insufficient. Each runtime
proof uses network-none, 2 CPUs, 4 GiB memory with no swap, pids limit 512, UID 0
as in native Nix CI, and no privilege, added capabilities, host namespace, host
mount, store/cache or Docker socket. The pids limit is a proof constraint, not a
claim about the build flag or current agent defaults. A deadline is a failure
ceiling, never a success condition.

The six cases are the canonical baseline, two fresh current-source executions at
each forge-resolved workspace path, and an unkeyed failing current-source test
under hostile inherited selectors. The canonical run is a separate fresh COW
container. Its independent observer first fully validates the candidate manifest,
then verifies all five canonical environment input files byte-for-byte against
the candidate. Only that observer uses the same internal execution body for the
canonical baseline; there is no public key-bypass flag. Normal CLI execution
always validates the complete current-source key.

Record full logs and process exits. Compare every expected Python family, the
Node test summaries with the same reporter, and the Bash summary
`=== tests: N files, pass=X fail=Y skip=Z` against that actual canonical run.
Account separately for the added checker's source-bound focused-test family.
Require every expected family, no additional skips and successful positive runs.
A functional-lane summary is not a full development-gate baseline. The admitted
devenv 2.4.0 `--verbose` output prefixes live summaries with exactly two ASCII
spaces. Parse that observed live channel consistently; never trim arbitrary
whitespace or accept timestamped failure-report replay as live output.

For the current-source negative, copy
`tests/fixtures/offline-current-source-negative.test.sh.fixture` to
`tests/unit/offline-current-source-negative.test.sh` only in an owned disposable
checkout. Keep the environment key unchanged. Supply hostile inherited `K`,
`AU_TEST_FILTER`, `AU_SMOKE_ONLY`, `MAKEFLAGS`, `MFLAGS` and `GNUMAKEFLAGS`.
The complete gate must execute the actual harness failure record and exit
nonzero; a marker substring alone is insufficient. Never commit this failing
fixture. Missing-CLI and corrupt-npm faults must also fail for their exact
required reasons. Preserve full private evidence and publish only safe summaries,
never credentials or raw sensitive diagnostics.

After admission, the trusted operator publishes only
`ghcr.io/bolens/audio-utils:ci-env-KEY` with the existing approved package
credential in a private push configuration. Refuse a conflicting existing tag;
matching content does not require a rewrite. Resolve the immutable public
manifest, bind its config/content identity to the admitted image, and pull it
anonymously. Only then select that digest through a protected consumer change.
The toolchain tag is not a product release and never updates runtime aliases.

## Consumer and successor changes

The existing `development-environment` step in `.woodpecker/woodpecker.yml` pins
the admitted manifest, sets step-level `network_mode: none` and runs:

```sh
/opt/audio-ci/python /opt/audio-ci/offline_environment.py run --root "$CI_WORKSPACE"
```

Its checker validates the complete key and invokes the pinned devenv CLI with
`--verbose --max-jobs 1 --cores 2 --offline test`. The actual current checkout
must match the execution root. Woodpecker's Docker workspace base is distinct
from its generated script's forge-resolved process directory; both contract
paths are covered by admission. Successful task output is observed using the
exact two-space live prefix and actual Python, Bash and Node summaries.

The selected devenv 2.4.0 toolchain was admitted at source
`26db8d162999b37327a99f52302ee6edc1323d91`, including all six runtime cases,
both fault cases, the content audit and terminal container lifecycles. Its
environment key is
`52d9292531c0c05f426bcd3efc8ae75b07839a0b719961e5e7f3c2624c8d94c7`.
The published manifest
`ghcr.io/bolens/audio-utils@sha256:d47c605bdec64e8cf8c5d147bdc61d04230f9293f5fa87d71ab676d27198c52a`
was verified by an anonymous immutable pull. Consumer workflow and documentation
changes preserve that key; protected PR/main delivery still verifies the final
source through the selected image.

Regenerate the credential-free mirror with
`python3 scripts/ci/sync-woodpecker-validation.py --write`, then `--check`.
Keep all six workflow basenames, required checks, publication dependencies and
repository trust settings unchanged. Require actual current-head PR and genuine
merged-main validation, then reconcile Gitea through its protected validation-only
profile while preserving its four governance overlays.

For a lock/declaration update, first prepare and admit a successor image, publish
and publicly verify it, then review the new inputs and digest together. Rollback
uses a normal protected change to an accepted compatible source/key/digest pair.
A mismatch never triggers an online fallback or a shared writable cache.

## Retained workflow boundaries

This image replaces only the native Linux Nix step; it does not make the other
five distribution/tool/minimum-runtime lanes network-independent. Retain hosted
macOS, actual Docker runtime acceptance, exported Docker development-image and
VS Code devcontainer checks, plus their required aggregate. The hosted Linux Nix
fallback remains controlled by `WOODPECKER_NIX_CI`; Nix/devenv setup also serves
the retained Docker export test.

The hosted exact-image publication bridge retains scoped permissions and full
Docker acceptance. Product signed-tag/release and signing/OIDC responsibilities
remain outside this dependency image; no signing credential enters the consumer.
Labeling, assignment and Spec Kit update PR creation remain host administration.
Keep the established two-flag portable/publication fallback and the separate Nix
fallback. For publication rollback, drain native/hosted publishers, select the
validation-only profile, then clear the publishing flag in the documented order.
