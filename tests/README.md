# Tests

Harness: [`run.sh`](run.sh) / [`harness.sh`](harness.sh). Fixtures: [`fixtures.sh`](fixtures.sh).

```bash
make test                 # unit + smoke
make test-functional      # needs ffmpeg/flac
make test-all
make test K=playlist      # narrow by filename pattern
```

A `K` filter that matches no test file or function exits `2`; this prevents a
mistyped focused check from being reported as a successful zero-test run.

Layout:

| Dir | Role |
|-----|------|
| `unit/` | Pure lib / helper tests (no media encode) |
| `smoke/` | `--help` / bad flag / dry-run per tool |
| `functional/` | Encode/decode and util behavior |

New tools: smoke coverage is automatic when the tool Makefile is discoverable; add a `functional/*.test.sh` when behavior needs a real fixture.

## CI dependency reuse

A preparation job builds the pinned APE and keyfinder dependencies once for all functional shards. Successful installations have separate caches keyed by their installer recipes, architecture, and hosted-runner image version. Cache hits skip compilation and failed optional builds are never cached. Both FFmpeg legs still run the same functional tests, and missing optional tools still count toward the existing skip limit. A declared ready cache that cannot be restored fails explicitly.

The installer tests remain isolated and run normally. The existing generated-fixture and npm caches are unchanged. Current-upstream FFmpeg is still downloaded fresh so the latest-version leg does not become a stale cached release.

## Fedora lint scheduling

Fedora runs the same `make check` coverage as before: one matrix job runs `make check-shared` for the shared library, MCP scripts, tests, action pins, documentation links, and generated references. Eight other matrix jobs partition the complete conversion and utility lists by index. Each tool appears in exactly one shard, and each shard uses the runner CPU count for parallel checks. The CI aggregate waits for every shard and fails if any fails. The pinned Fedora container and existing path/scheduled-run triggers are unchanged.

Both the runner and direct harness invocation isolate HOME, XDG config/state/cache/data/runtime paths, and TMPDIR in disposable directories.

Mixed valid/corrupt WAV batches run with one and two workers in `converter-edge-cases.test.sh`. Checks cover failure reporting, decoded output equivalence, byte-for-byte source retention, and absence of output for the corrupt input.

`make test-docker` builds the runtime image and tests disposable bind-mounted
fixtures, non-root ownership, read-only root operation and CLI failure behavior.
It requires Docker and host Python 3.11+. `CONTAINER_ENGINE=podman` uses rootless
Podman locally. Docker CI runs this target on every PR and main push.

Publication regressions force the final move to fail after real codec verification.
They cover PCM, lossless and lossy pipelines with one and two workers, deletion
requested, and retagging an existing FLAC. Failures must retain sources, preserve
existing output, return nonzero and omit success rows. Docker also checks an
actual read-only input mount.

## Change selection

Manual and scheduled CI runs select every suite. Shared library changes also
select the MCP tests. Removed tools and category-level inputs select all surviving
tools in that group; newly nested tool Makefiles remain discoverable. Invalid
changed-file JSON fails planning. The required CI gate validates filter outputs
and requires every selected job to succeed; only unselected jobs may skip.
