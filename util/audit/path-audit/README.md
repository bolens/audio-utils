# path-audit

Read-only filename portability audit: FAT/exFAT/NTFS-illegal characters,
control characters, trailing dots/spaces, reserved DOS names, components over
255 bytes, non-UTF-8 names, and case-fold collisions. Every ancestor component
is checked once; Unicode NFC collisions are also detected when `uconv` is
available. `--max-path=N` adds a full-path byte-length check (e.g. 260 for
Windows targets).

Fix offenders with [`util/flac-rename`](../../flac/flac-rename/) or by hand.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit file / directory names for portability (FAT/exFAT/NTFS, length, UTF-8).

Usage:
  path-audit.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --max-path=N    Also fail when the full path exceeds N bytes (e.g. 260)

Read-only: -d / -D / -y rejected. Fix names with util/flac-rename.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
