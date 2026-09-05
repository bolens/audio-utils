# path-audit

Read-only filename portability audit: FAT/exFAT/NTFS-illegal characters,
control characters, trailing dots/spaces, reserved DOS names, components over
255 bytes, non-UTF-8 names, and case-fold collisions. Every ancestor component
is checked once; Unicode NFC collisions are also detected when `uconv` is
available. `--max-path=N` adds a full-path byte-length check (e.g. 260 for
Windows targets).

Fix offenders with [`util/flac-rename`](../../flac/flac-rename/) or by hand.

Part of **[audio-utils](../../../)**.

## Choosing a target policy

Default checks focus on component portability. Add `--max-path 260` for a
legacy Windows-style byte budget or choose a limit matching the actual target
and mount point.

```bash
./path-audit.sh /path/to/library
./path-audit.sh --max-path 260 /path/to/library
```

Case-fold and normalization collisions matter even on a case-sensitive Linux
source because two distinct names may collapse when copied elsewhere. `iconv`
improves UTF-8 validation and `uconv` enables NFC collision checks; unavailable
optional tools reduce those checks but do not make names portable by default.

The audit is read-only and rejects `-d`, `-D`, and `-y`. Rename in controlled
batches, update playlists/CUE references, and rerun after fixes.

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
