# multi-disc-layout

Normalize multi-disc albums into `Disc N/` subfolders from `DISCNUMBER` /
`TOTALDISCS` tags. Report-only by default; `--apply` moves files.

An album is multi-disc when any track has `DISCNUMBER>1` or `TOTALDISCS>1`.
Single-disc albums stay flat. Folder prefix defaults to `Disc` (`--prefix`).

Companion to [`util/flac/flac-rename`](../../flac/flac-rename/) (filenames) and
[`util/audit/album-audit`](../../audit/album-audit/) (track gaps).

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
multi-disc-layout - put multi-disc albums into Disc N/ folders from tags.

Usage:
  multi-disc-layout.sh DIR [DIR ...]
  find-flac-dirs.sh | multi-disc-layout.sh --apply

Options:
  --apply           Move files (default: report candidates as failures)
  --prefix=NAME     Folder prefix (default: Disc -> "Disc 1")
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Multi-disc when any track has DISCNUMBER>1 or TOTALDISCS>1. Single-disc albums
are left flat. Prefer setting TOTALDISCS on all tracks.

-d / -D rejected.
Exit codes: 0 ok, 1 candidates/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
