# multi-disc-layout

Normalize multi-disc albums into `Disc N/` subfolders from `DISCNUMBER` /
`TOTALDISCS` tags. Report-only by default; `--apply` moves files.

An album is multi-disc when any track has `DISCNUMBER>1` or `TOTALDISCS>1`.
Single-disc albums stay flat. Folder prefix defaults to `Disc` (`--prefix`).

Companion to [`util/flac/flac-rename`](../../flac/flac-rename/) (filenames) and
[`util/audit/album-audit`](../../audit/album-audit/) (track gaps).

Part of **[audio-utils](../../../)**.

## Planning and collision safety

Report mode derives each FLAC destination from its disc tags and shows files
that should move. A custom prefix changes folder labels without changing disc
numbers.

```bash
./multi-disc-layout.sh /path/to/albums
./multi-disc-layout.sh -n --apply --prefix CD /path/to/albums
```

`--apply` creates the required disc directory and moves the FLAC. It does not
rewrite tags, rename track filenames, or silently overwrite destination
collisions. Files lacking coherent disc tags need correction before layout can
be trusted.

Generic `-y`, `-d`, and `-D` are rejected; movement requires explicit
`--apply`. Update external playlists or CUE references after reorganizing and
rerun `album-audit` on the resulting layout.

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
