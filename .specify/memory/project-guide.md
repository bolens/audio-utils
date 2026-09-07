# audio-utils Spec Kit project guide

[Documentation](../../docs/README.md)

GNU/Linux Bash audio conversion and library utilities with a shared preservation
pipeline and MCP gateway.

Read this guide with `AGENTS.md` and `.specify/memory/constitution.md` before
specifying, planning, or implementing a substantial change. It is project-owned
guidance, not an upstream-managed template.

## Source and ownership map

- `lib/README.md`
- `lib/plugin_init.sh`
- `lib/load.sh`
- `conversion/`
- `util/`
- `mcp/`
- `tests/README.md`

## Specification and plan decisions

Identify the converter or utility and its shared pipeline seam. Specify input/output
formats, verification, atomic publication, source retention, stdout/stderr roles, and
exit codes. Keep shared modules side-effect-free when sourced and tool wrappers thin.

## Acceptance evidence

Use disposable media fixtures to cover spaces, newlines, leading dashes, Unicode,
corrupt input, missing dependencies, partial output, and verification failure. Source
deletion must remain gated by explicit intent and successful verification.

## Validation and operational limits

```sh
make check
make test
```

Start with the relevant target documented in tests/README.md; use make test-all for
broader release coverage. Report missing codec, tagging, hardware, or proprietary-tool
cases. Never test writes, renames, or cleanup against a real library.

## Working through Spec Kit

Use Spec Kit for new capabilities, architectural or security-sensitive changes,
migrations, and coordinated changes that need a written contract. Keep narrow fixes,
dependency updates, and prose maintenance in the normal PR workflow.

For a new feature, record observable acceptance criteria in `spec.md`, source ownership
and constitution checks in `plan.md`, and evidence-bearing work in `tasks.md` under the
feature directory created by Spec Kit. Resolve material unknowns before implementation.
Mark tasks complete only after their stated verification, and distinguish completed,
skipped, blocked, and manual checks. Retain completed feature documents as decision
history. Backfill finished work only when explicitly requested. Label those
specifications as retrospective baselines, record the inspected revision, and map
requirements to source and acceptance evidence. Separate observed behavior from
corrective requirements. Never imply the specification preceded its code or mark
unverified checks complete.

Keep `.specify/templates/`, `.specify/scripts/`, and generated Codex skills under their
integration manifests. Use this guide and the constitution for local customization.
Regenerate managed files through Spec Kit and verify that project-owned memory survives
updates. Follow `RELEASING.md` for push, merge, release or delivery, and recovery.

The retrospective specification register is [specs/README.md](../../specs/README.md).
