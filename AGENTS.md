# Agent guidance

Before Spec Kit planning or implementation, read
`.specify/memory/project-guide.md` with the project constitution. It maps
requirements to this repository's source, acceptance evidence, and validation.

Read `.specify/memory/constitution.md` and the nearest contract document:
`lib/README.md`, `tests/README.md`, `docs/adding-a-converter.md`, or
`docs/adding-a-util.md`.

- Target GNU/Linux and Bash 4.3+. Executables use Bash with
  `set -euo pipefail`; preserve exit codes `0` success, `1` operation failure,
  and `2` usage/dependency failure.
- Preserve filenames exactly, including spaces, leading dashes, glob
  characters, Unicode, and newlines. Prefer arrays, `--`, and NUL-delimited
  traversal.
- Keep tool directories thin. Load shared code through `lib/plugin_init.sh`
  and `lib/load.sh`; shared modules do no work when sourced.
- Use the scaffolds for new converters and utilities. Keep root Makefile/CI
  autodiscovery intact.
- Never test conversion, tagging, rename, cleanup, prune, or deletion against a
  real media library. Use the repository harness or disposable fixtures with
  isolated HOME/XDG/TMPDIR. Network enrichment stays explicit and opt-in.
- Preserve verification, atomic output, source-deletion guards, and read-only
  utility behavior.
- Run the smallest relevant Make target first. Use `make check-lib`,
  `make check-mcp`, or `make check-tests` for shared surfaces; widen to
  `make check`, `make test`, or `make test-all` as risk requires. Report skips.
- Update user-facing help and indexed docs when behavior, flags, dependencies,
  or formats change. Never edit `VERSION` or publish/install artifacts unless
  explicitly requested.

## Spec-driven changes

Use Spec Kit for new capabilities, architecture, security-sensitive behavior,
migrations, and coordinated multi-file changes. Keep narrow fixes, dependency
updates, prose edits, and release housekeeping in the normal repository
workflow unless their risk warrants a written specification. Keep completed
feature directories under `specs/` as decision history; do not backfill them for
finished work.

## Context and handoffs

- Locate source with targeted searches before reading. For exploratory reads of
  files over 350 lines, select relevant ranges. Read required guidance and actual
  source before edits or correctness claims; summaries do not replace them.
- When delegation is permitted, give each worker one question or concrete output,
  allowed paths, and a check. Return findings with source locations, changed paths,
  and verification gaps. Keep final review with the coordinating agent.
- Record durable user corrections in the [project guide](.specify/memory/project-guide.md)
  or owning contract with scope, reason, and evidence. Replace superseded advice;
  read relevant corrections before reusing assumptions. Keep temporary progress
  in task notes and preserve existing authority rules.
