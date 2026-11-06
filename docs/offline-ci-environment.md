# Offline CI environment (candidate)

This prototype prepares a public toolchain image for the existing Audio development
gate. It is not selected by either live Woodpecker profile. An image build or a
successful shell warmup does not establish offline readiness.

## Inputs and source ownership

`ci/offline-environment/contract.json` binds Linux amd64, the existing Nix base
digest, the exact devenv CLI revision, `devenv.nix`, `devenv.yaml`, `devenv.lock`,
and both npm dependency files. The explicit CLI-source NAR pin is also part of the contract and key. Nix 2.35
flake metadata can name a virtual store path without registering its source;
preparation must materialize and verify that pinned root before admitting it.
The recipe, checker and preparation script are also keyed. The conservative declaration inventory includes whole mixed installer,
hook, Makefile and fixture-generator files; edits to those bodies can require an
unnecessary environment rebuild. Ordinary `lib/` implementation and unit or
functional test bodies are excluded from the key and always run from the current
checkout. Consuming workflow files are excluded to avoid a digest/key cycle.

Unknown Nix imports, local overrides, symlinks and untracked dependency declarations
are refused. New fetchers need an inventory review. Network isolation is the final
boundary: Nix `--offline` alone does not block operating-system network access.

Late preparation diagnostics expose only fixed phase names, numeric counts and
exact known static guard messages. Arbitrary JSON, operating-system, subprocess
and cache values stay redacted; unknown failures never establish readiness.

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
to the build. Two sequential Dockerfile RUNs share the same pinned base and private
store/database. The first copies only five environment files, `.gitignore` and
stable realization/bootstrap scripts, then realizes the CLI, shell/test outputs
and npm content. The second copies the full public allowlist and runs with operating-system
networking disabled. It materializes only the exact CLI root source from Nix's
cached source tree, binding the reviewed revision and explicit NAR hash, then
serializes the manifest/checker using the already realized Python/profile. It
does not build dependencies, evaluate their outputs or recursively archive inputs.
Late checker/provenance changes reuse the successful first layer; environment or
bootstrap changes invalidate it. A missing cached source fails closed offline.

Both RUNs check actual cgroup limits before work: 2 CPUs, 4 GiB RAM and no swap.
Unsupported `buildx --resource` enforcement fails before downloads. The guard is
part of the cached realization recipe itself. Runtime proof additionally uses
pids limit 512; the build resource option does not promise that limit. A deadline is a failure ceiling, never a
success condition.

An independent operator must bind the resulting image ID/digest and manifest key,
verify declared store content with Nix content/NAR verification, inspect final
filesystem/history for secrets and application source, then run this image with:

- `--network=none`, no host Nix store, cache, socket, privileges or shared writes;
- a fresh container COW store/database and fresh HOME/XDG state for every run;
- each forge-resolved workspace path from the contract and default random `.devenv.*`;
- the current tracked checkout, not the preparation snapshot;
- `run --root CHECKOUT`, which executes exact pinned devenv with
  `--verbose --max-jobs 1 --cores 2 --offline test` and npm forced offline.

Pinned devenv hides successful task output by default. Global `--verbose` exposes
it with the exact `[devenv:enterTest] ` prefix; remove only that prefix when
parsing summaries, not timestamped failure-report replay.

Record full logs and process exits. Existing successful native status alone may
not expose counts. First run the accepted canonical source in a separate fresh
offline container, verifying all five environment files byte-for-byte against the
fully validated candidate manifest. That independent observer baseline uses the
same internal execution body, not a public key-bypass flag. Normal execution
always checks the complete current-source environment key.

Compare the candidate's full gate with the actual canonical baseline: each Python
family, Node test summaries and the Bash runner's
`=== tests: N files, pass=X fail=Y skip=Z`. Account separately for the added helper's
source-bound focused test family. Require the same Node reporter, every expected
family, no additional skips and success. The separate functional lane's summary
is not this full-gate baseline. Source locations are
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
