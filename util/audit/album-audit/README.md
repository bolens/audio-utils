# album-audit

Read-only album-level consistency check, one result per directory: track
number gaps and duplicates (per disc), missing track/album tags, mixed
ALBUM / ALBUMARTIST / DATE values, various-artists folders without
ALBUMARTIST, mixed sample rate or bit depth (FLAC), and TOTALTRACKS
mismatches.

Per-file checks live in [`util/flac-audit`](../../flac/flac-audit/) and
[`util/lossy-audit`](../lossy-audit/); this tool reasons about the album as a
unit.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit albums (directories): track gaps/dupes, mixed album/artist/date,
mixed sample rate or bit depth, TOTALTRACKS mismatch.

Usage:
  album-audit.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected. One result per directory.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
