# Plan: Verified audio workflows and shared utility engine

The [specification](spec.md) preserves existing behavior. Use the project guide
and constitution for implementation constraints. Keep upstream-managed templates,
helpers, and integration manifests unchanged.

## Source ownership

- `lib/README.md`
- `lib/load.sh`
- `lib/plugin_init.sh`
- `lib/cli`
- `lib/core/delete.sh`
- `lib/pipeline`
- `lib/media`
- `conversion`
- `util`
- `mcp/server.sh`
- `tests`

## Constitution check

Preserve the existing constitution, canonical source ownership, explicit operational authority, deterministic failure behavior, and native validation. This retrospective baseline changes project-owned documentation; it introduces no live deployment, credentials, privileged action, or product release.

## Validation

```sh
make check test-all JOBS=2
make test-functional K=tags-lookup
make test K=mcp
cd mcp/npm && npm ci && npm test
```

Run checks in an isolated checkout. Commands are instructions, not evidence of
a pass. Record results in `coverage.md`, keep incomplete work in `tasks.md`, and
follow `RELEASING.md` for reviewed delivery. No live operation is required solely
to create this retrospective baseline.

## Legacy audit implementation, 2026-09-06

Adopt the detailed tool documents through `legacy-contracts.md` and map all
94 commands plus supporting interfaces in `legacy-coverage.md`. Keep upstream
Spec Kit files and the separate development-environment PR outside this change.

Correct the harness's conditional subshell before using old acceptance fixtures
as evidence. Reconcile newly visible failures by distinguishing product defects,
incorrect assertion syntax, report-file semantics, metadata container differences,
and unavailable binaries. Preserve failed-run evidence in the delivery review.

Keep duplicate paths encoded in their private TSV indexes and link counts free
of path delimiters. Preserve locking and the registered keeper's identity.
Use separate stream verification directories owned by the existing parent
workspace. Validate album members before moves, then accept subsequent queued
members of an already claimed album. Add junk-only discovery selectors before
existing exclusions and acceptance filtering. Escape XML without Bash replacement
ampersand expansion. Validate converter separators before creating directories.

Run the corrected entire harness, native lint/documentation checks, optional MCP
fixtures where available, and the container gate. Review the full candidate
separately and verify the actual merge revision before closing delivery tasks.
