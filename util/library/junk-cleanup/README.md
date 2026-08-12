# junk-cleanup

Find OS litter beside audio: `Thumbs.db`, `desktop.ini`, `.DS_Store`,
`.directory`, AppleDouble `._*` files, and zero-byte files. Report-only by
default (exit 1 when junk is found); `-d` deletes.

Companion to [`util/pcm-cleanup`](../pcm-cleanup/) (leftover PCM).

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Report (or delete) junk files: Thumbs.db, desktop.ini, .DS_Store,
.directory, AppleDouble ._*, zero-byte files.

Usage:
  junk-cleanup.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  -d              Delete junk (default: report-only, exit 1 when junk found)

-D / -y rejected.
Exit codes: 0 clean, 1 junk found/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
