# Agent guidance

[Documentation](docs/README.md) maps architecture, deployment, state, and document ownership.

Read [.specify/memory/constitution.md](.specify/memory/constitution.md) and the nearest contract document:
[lib/README.md](lib/README.md), [tests/README.md](tests/README.md), [docs/adding-a-converter.md](docs/adding-a-converter.md), or
[docs/adding-a-util.md](docs/adding-a-util.md).

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

## Planning and evidence

Use the [project guide](.specify/memory/project-guide.md) and
[constitution](.specify/memory/constitution.md) for substantial changes. The guide
owns Spec Kit scope, retained history, retrospective requirements, and acceptance
evidence. Prose maintenance uses the normal repository workflow.

## Context and handoffs

- Search before reading. Use bounded source excerpts for exploratory reads over
  350 lines, and inspect required guidance and actual source before editing.
- When delegation is permitted, assign a bounded question or output, paths, and
  check. Return source locations, changes, and verification gaps for final review.
- Keep durable corrections in the [project guide](.specify/memory/project-guide.md)
  or owning contract. Replace superseded advice and read it before reuse.
  Temporary progress belongs in task notes. Preserve existing authority rules.
