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
