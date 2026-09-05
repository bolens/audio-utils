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
