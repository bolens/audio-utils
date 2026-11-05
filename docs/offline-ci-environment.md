# Offline CI environment (candidate)

This prototype prepares a public toolchain image for the existing Audio development
gate. It is not selected by either live Woodpecker profile. An image build or a
successful shell warmup does not establish offline readiness.

## Inputs and source ownership

`ci/offline-environment/contract.json` binds Linux amd64, the existing Nix base
digest, the exact devenv CLI revision, `devenv.nix`, `devenv.yaml`, `devenv.lock`,
and both npm dependency files. The recipe, checker and preparation script are also
keyed. The conservative declaration inventory includes whole mixed installer,
hook, Makefile and fixture-generator files; edits to those bodies can require an
unnecessary environment rebuild. Ordinary `lib/` implementation and unit or
functional test bodies are excluded from the key and always run from the current
checkout. Consuming workflow files are excluded to avoid a digest/key cycle.

Unknown Nix imports, local overrides, symlinks and untracked dependency declarations
are refused. New fetchers need an inventory review. Network isolation is the final
boundary: Nix `--offline` alone does not block operating-system network access.

The context command accepts only clean committed source and copies the explicit
public environment/recipe allowlist, plus source identity and declaration hashes.
It does not copy the application checkout, `.git`, credentials or host caches.
The final image retains the private builder's Nix store/database, declared public
input sources, selected fetcher metadata and verified npm content. It must not
retain executable copies of an old application checkout.

## Preparation and proof

After source review and a normal reviewed commit, an operator can generate an
owned context with `python3 scripts/ci/offline_environment.py context --output DIR`.
Preparation may reach only public upstreams; no registry credentials are supplied
to the build. The sole Dockerfile RUN checks actual cgroup limits before fetching:
2 CPUs, 4 GiB RAM and no swap. Unsupported `buildx --resource` enforcement fails
before downloads. Runtime proof additionally uses pids limit 512; the build resource
option does not promise that limit. A deadline is a failure ceiling, never a
success condition.

An independent operator must bind the resulting image ID/digest and manifest key,
verify declared store content with Nix content/NAR verification, inspect final
filesystem/history for secrets and application source, then run this image with:

- `--network=none`, no host Nix store, cache, socket, privileges or shared writes;
- a fresh container COW store/database and fresh HOME/XDG state for every run;
- each forge-resolved workspace path from the contract and default random `.devenv.*`;
- the current tracked checkout, not the preparation snapshot;
- `run --root CHECKOUT`, which executes exact pinned devenv with
  `--max-jobs 1 --cores 2 --offline test` and npm forced offline.

Record full logs and process exits. Compare the actual full development gate,
including each Python family, Node TAP results and the Bash runner's
`=== tests: N files, pass=X fail=Y skip=Z`, against the genuine accepted native
step; the separate functional lane's summary is not this baseline. Require every
expected family, no additional skips, and success. Source locations are
`scripts/check-development.sh`, `tests/run.sh:170`, and the npm test script.

For the negative proof, copy `tests/fixtures/offline-current-source-negative.test.sh.fixture`
to `tests/unit/offline-current-source-negative.test.sh` in an owned disposable
checkout. The environment key must remain unchanged. Run the complete gate with
hostile inherited `K`, `AU_TEST_FILTER`, `AU_SMOKE_ONLY`, `MAKEFLAGS`, `MFLAGS` and
`GNUMAKEFLAGS`; it must still execute the marker and fail. The runner constructs
an explicit environment rather than inheriting those selectors. Never add this
failing file to a published source tree.

## Proposed admission and consumption

Only after all proofs pass, a trusted operator may publish the exact image to the
existing approved public Audio GHCR package using an immutable `ci-env-KEY` tag.
Authentication belongs to the push operation, never Dockerfile arguments, context,
image layers or untrusted PRs. Reject tag collisions unless the existing digest
is exactly the admitted artifact. No broker extension or new credential scope is
part of this prototype.

A later reviewed change can pin that verified digest in the existing core workflow
step in `.woodpecker/woodpecker.yml`, set `network_mode: none`, and regenerate the
byte-identical validation profile. Keep all six existing workflow basenames,
required checks and publishing dependencies. Both forge paths must pass first. Docker Config.WorkingDir `/woodpecker` is the
workspace base, not the process directory: Woodpecker resolves
`src/forge-host/owner/repo` and its generated script changes directory there. The
Gitea process directory was independently observed; the GitHub path follows the
same pinned Woodpecker compiler contract.
The source checkout must remain available to the runner; test code is never baked
into the toolchain. Publishing steps retain their existing network and credential
policy and do not move into this environment.

Lock/declaration changes first prepare and prove a successor environment, then
atomically update the source locks and consuming digest in a reviewed PR. The old
pin remains usable for rollback. A mismatched key fails before tests, without a
network fallback. No live consumer or registry setting changes are authorized by
this document alone.
