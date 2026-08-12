# tree-diff

Compare files under library roots to the same relative paths in `--against`
(size, optional `--hash`). Useful for backup verification.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Diff scanned library files against another tree (--against).

Usage:
  tree-diff.sh --against=BACKUP_ROOT DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --against=DIR   Comparison tree (required)
  --hash          Also compare sha256

Relative paths resolved via AUDIO_UTILS_ROOTS.
Read-only: -d / -D / -y rejected.
Exit codes: 0 match, 1 diffs, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
