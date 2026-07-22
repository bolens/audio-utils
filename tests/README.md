# Tests

Harness: [`run.sh`](run.sh) / [`harness.sh`](harness.sh). Fixtures: [`fixtures.sh`](fixtures.sh).

```bash
make test                 # unit + smoke
make test-functional      # needs ffmpeg/flac
make test-all
make test K=playlist      # narrow by filename pattern
```

Layout:

| Dir | Role |
|-----|------|
| `unit/` | Pure lib / helper tests (no media encode) |
| `smoke/` | `--help` / bad flag / dry-run per tool |
| `functional/` | Encode/decode and util behavior |

New tools: smoke coverage is automatic when the tool Makefile is discoverable; add a `functional/*.test.sh` when behavior needs a real fixture.
