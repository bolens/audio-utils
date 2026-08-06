# AGENTS.md

Guidance for coding agents working in this repository.

## Repository at a glance

`audio-utils` is a GNU/Linux, Bash 4.3+ toolkit for verified audio conversion
and library maintenance. FLAC is the archive hub.

- `lib/core/`: generic plumbing (logging, config, XDG paths, temp files,
  progress, deletion, success logs)
- `lib/cli/`: shared CLI, driver, worker, discovery, and parallel execution
- `lib/media/`: audio probing, metadata, CUE, chapters, playlists, and FLAC
  helpers
- `lib/pipeline/`: shared conversion and disc pipelines
- `conversion/<tool>/`: format converters
- `util/<category>/<tool>/`: audits, metadata tools, reports, and maintenance
- `tests/{unit,smoke,functional}/`: test tiers and shared Bash harness
- `mcp/`: optional Bash MCP server and Node launchers

Read the nearest relevant docs before changing a contract:

- Shared library: `lib/README.md`
- New converter: `docs/adding-a-converter.md`
- New utility: `docs/adding-a-util.md`
- Tests: `tests/README.md`
- Platform and dependencies: `docs/requirements.md`

## Core rules

- Target GNU/Linux only. Do not add macOS, BSD, BusyBox, or Alpine
  compatibility unless explicitly requested.
- Write Bash, not POSIX `sh`. Executables use `#!/usr/bin/env bash` and
  `set -euo pipefail`.
- Use two-space indentation for shell and tabs for Make recipes.
- Keep CLI output plain text: no color, emoji, spinners, or in-place animated
  output. Send progress and diagnostics to stderr.
- Preserve exit-code semantics: `0` success, `1` operation/preflight failure,
  `2` usage/dependency/bad-argument failure.
- Quote expansions and use arrays for command arguments. Use `--` before
  user-controlled path operands where supported.
- Preserve filenames exactly. Audio paths may contain spaces, leading dashes,
  glob characters, Unicode, and newlines; prefer NUL-delimited traversal when
  passing paths between processes.
- Reuse shared library functions and a close peer tool before introducing
  tool-local copies.

## Architecture and contracts

Per-tool directories should stay thin: an entry script, `lib/plugin.sh`,
optional `lib/convert.sh`, discovery/batch wrappers, `Makefile`, README, and
`.shellcheckrc`.

- Entry scripts walk upward to find `lib/plugin_init.sh`, then source
  `lib/cli/cli.sh`. Do not hard-code repository depth.
- A plugin defines its `AU_*` contract before sourcing `lib/plugin_init.sh`.
- Shared modules are source-only and must not perform work while being loaded.
- Tools do not source individual shared modules directly; loading flows through
  `plugin_init.sh` and `lib/load.sh`.
- When adding a shared module, add it to `lib/load.sh` in dependency order and
  include the matching `# shellcheck source=` directive.
- Put generic plumbing in `core`, CLI/worker behavior in `cli`, audio-aware
  helpers in `media`, and reusable conversion flows in `pipeline`.
- Prefer shared extension groups from `lib/media/audio_exts.sh`.
- The root Makefile and CI auto-discover tool directories containing a
  Makefile. Do not manually register them.

For new tools, use the scaffold rather than copying by hand:

```bash
make new-converter NAME=flac-to-xyz
make new-util CATEGORY=flac NAME=flac-frob
```

Then update the root README inventory, relevant dependency/topic docs, and
functional coverage. Read-only utilities must reject deletion flags and set the
appropriate `HAS_DELETE=0` Make variable.

## Safety

Never run conversion, cleanup, rename, tagging, pruning, or delete targets
against a user's real media library while developing or testing.

- Do not infer or reuse the user's `AUDIO_UTILS_ROOTS`.
- Prefer repository tests; they sandbox HOME, all XDG directories, and TMPDIR.
- For manual checks, create disposable fixtures under a fresh temporary
  directory and explicitly point the command there.
- Treat `-d`, `-D`, `--apply`, cleanup/prune targets, and non-dry-run batch
  targets as destructive.
- Do not weaken sibling verification, source deletion checks, temp-file
  cleanup, or atomic-output behavior.
- Network enrichment must remain explicit and opt-in.

## Validation

Run the smallest relevant checks first, then widen in proportion to the change.

```bash
# One tool: ShellCheck, automatic smoke, and matching tests
make -C conversion/<tool> test
make -C util/<category>/<tool> test

# Narrow tests by test filename or function name
make test K=<pattern>
make test-functional K=<pattern>

# Shared areas
make check-lib
make check-mcp
make check-tests

# Repository-wide
make check
make test
make test-functional
make test-all
```

`make test` runs unit and smoke tests. Functional tests require audio
dependencies such as `ffmpeg` and `flac`; dependency-based skips are acceptable
when reported by the harness. Do not claim a skipped tier passed.

Validation expectations:

- Tool-local change: tool `test` target.
- Shared `lib/` change: focused tests, `make check-lib`, then `make test`.
- Test harness or `scripts/` change: `make check-tests` and affected tests.
- MCP Bash change: `make check-mcp` and `make test K=mcp`.
- Cross-cutting pipeline or release-ready change: `make check` and
  `make test-all` when dependencies are available.

Add unit tests for pure helpers and functional tests for observable conversion
or utility behavior. Smoke coverage is automatic for discoverable tools.
Tests must be deterministic, offline by default, and must not inspect or mutate
real user state.

## Change discipline

- Inspect a close existing tool and its tests before implementing a variant.
- Keep changes focused; do not reformat unrelated files or update generated
  artifacts without cause.
- Preserve user changes in a dirty worktree.
- Update help text, README inventory, requirements, and topic docs whenever
  behavior, flags, dependencies, or supported formats change.
- Do not edit `VERSION` or publish/install artifacts unless explicitly asked.
- Report which checks ran, their result, and any skips or missing dependencies.
