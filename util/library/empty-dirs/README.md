# empty-dirs

Report empty directories left after prune/cleanup (artist/album shells with
nothing inside). Report-only by default (exit 1 when empties are found);
`-d` removes them with `rmdir`.

Pipe [`find-empty-dirs.sh`](find-empty-dirs.sh) for a deepest-first walk under
roots, then re-run after `-d` if parents become empty.

Companion to [`util/library/library-prune`](../library-prune/) and
[`util/library/junk-cleanup`](../junk-cleanup/).

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
empty-dirs - report or remove empty directories left after prune/cleanup.

Usage:
  empty-dirs.sh DIR [DIR ...]
  find-empty-dirs.sh | empty-dirs.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -d       remove empty directories (default: report as failures)

Pass empty dirs directly, or pipe find-empty-dirs.sh (deepest first).
Re-run after -d if parents become empty.

-D / -y rejected.
Exit codes: 0 ok, 1 empty dirs found (report) or remove failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
