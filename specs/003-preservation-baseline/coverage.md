# Requirement coverage

| Requirement | Source and acceptance evidence |
| --- | --- |
| FR-001 | `lib/plugin_init.sh`, `lib/load.sh`, `lib/README.md`, contract/source-only and wrapper tests. |
| FR-002 | Shared PCM/lossless/lossy pipelines, converter-edge-cases and publication-failure fixtures; lossy derivatives retain their separate contract. |
| FR-003 | `lib/core/delete.sh`, pipeline DELETE_SOURCE/cleanup branches, deletion and failed-publication fixtures. |
| FR-004 | Shared driver/CLI, `specs/001-batch-exclusions`, functional dry-run and exclusion fixtures. |
| FR-005 | Shared worker/driver/run_parallel, finalizer contract, mixed valid/corrupt and report-publication tests. |
| FR-006 | `mcp/server.sh`, `mcp/lib.sh`, Node gateway, and MCP smoke/unit tests. |

## Verification receipt

The native gate passed 497 tests with 10 explicit skips. A subsequent six-case tags-lookup run passed without its five sandbox-related skips. After locked optional Node dependencies were installed, all 31 MCP Bash fixtures and all eight HTTP gateway tests passed with zero skips. Four optional rsgain/loudgain and keyfinder cases remain unavailable locally. Separate self-review traced plugin loading, verification-before-publication and source-deletion guards, dry-run/exclusion behavior, finalizer failure reporting, and MCP destructive/network authorization. These results do not claim an unavailable codec or a live media-library check passed.

## Legacy completion receipt, 2026-09-06

[Legacy contracts](legacy-contracts.md) and [coverage](legacy-coverage.md) map all
35 converters, 59 utilities, and supporting interfaces to detailed requirements.
The earlier receipt above predates a harness defect: an OR-list disabled Bash
errexit inside test functions, allowing an early failed assertion to be hidden
by a later successful command. Its counts do not prove all assertions passed.

| Corrective requirement | Source and acceptance evidence |
| --- | --- |
| FR-007 | `tests/harness.sh`; `tests/unit/test-runner.test.sh` proves an early failed assertion returns failure and prevents the next mutation. The new fixture failed before the repair. |
| FR-008 | Audio/FLAC/hardlink duplicate registries and dependency checks; `inventory-dupes.test.sh` verifies encoded tab/newline paths and failed index writes; `shortlist-utils.test.sh` verifies keeper inode, unchanged bytes, and exact counts with one/two workers. |
| FR-009 | Shared lossless/playlist libraries, junk discovery, multi-disc layout, CUE export and tool scaffolder; streams-disc, hash-junk, small-utils, cue-export, playlist and new-tool fixtures. Album corruption prevents all moves; output directory collisions fail CUE publication without nesting files or deleting source tracks. |

With the corrected harness, the first full run exposed 18 failures. Source fixes
addressed XSPF escaping, duplicate index records, reused stream-verification workspaces,
empty/AppleDouble junk discovery, album queue paths already moved, incomplete CUE
pairs, and ambiguous converter names. Separate review additionally reproduced and
fixed unchecked CUE publication and duplicate-index I/O failure reporting.

The remaining failures were stale assertions or unavailable optional binaries:
MCP grep helper arguments/literal-array regexes, stream-level Ogg tags, case-preserved
CAF tag keys, playlist-header counting, producer SIGPIPE, directory assertions,
successful-run log cleanup, APE `-d` versus `-D`, and missing audio-key backend exit
status. They were reconciled against existing source/interface contracts. Broken
installed ReplayGain/keyfinder binaries are now explicit skips, not passing tests.

`make check test-all JOBS=4` passed: 63 files, 506 tests, zero failures, 10 skips.
Five skips were sandbox loopback restrictions: a subsequent local-stub run passed
all six lookup and 31 MCP fixtures with zero skips. The optional Node gateway passed
all eight tests. The five remaining skips are three ReplayGain and two keyfinder
cases with unrunnable optional binaries. Later index read-error handling passed
its targeted registry/hardlink checks. Docker build/acceptance passed with zero
skips using disposable fixtures through pkexec. All feature-local Markdown links
resolve. No personal media or live enrichment service was used.

Separate self-review checked the full candidate, corrected failure dispositions,
all tool mappings, source retention, filename encoding, worker aggregation, and
explicit mutation gates. No independent reviewer was used. Candidate CI and
exact merge-SHA/GHCR digest verification remain delivery gates recorded by the PR.
