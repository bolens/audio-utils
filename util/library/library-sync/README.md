# library-sync

For each FLAC under the archive roots, require a matching portable sibling
(same relative path, `.mp3` / `.opus` / …) under `--portable-root`.

Part of **[audio-utils](../../../)**.

## Root mapping

The archive root comes from the first configured `AUDIO_UTILS_ROOTS` entry.
For `Artist/Album/Track.flac`, the tool looks beneath `--portable-root` for the
same stem with any allowed extension. The default extension set is the shared
lossy cluster; `--exts mp3,opus` narrows it.

```bash
AUDIO_UTILS_ROOTS=/srv/music-flac \
  ./library-sync.sh --portable-root /srv/music-portable /srv/music-flac
```

## What a successful check means

Success means at least one same-relative-path portable file exists. This is a
structural completeness audit: it does not decode the portable file, compare
tags, or establish that it was derived from the current FLAC. Run the relevant
codec audit separately when content health matters.

Missing siblings produce exit status `1` and identify the stem and extensions
searched. The operation is read-only and rejects `-d`, `-D`, and `-y`.
[`library-prune`](../library-prune/) performs the inverse check from portable
files back to masters.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Check each FLAC has a portable sibling under another library root.

Usage:
  library-sync.sh --portable-root=DIR DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --portable-root=DIR   Required portable/lossy library root
  --exts=mp3,opus,m4a   Sibling extensions (default: AU_AUDIO_EXTS_LOSSY)

Requires AUDIO_UTILS_ROOTS (or scanned dirs under it) to resolve relative paths.
Read-only: -d / -D / -y rejected.
Exit codes: 0 ok, 1 missing siblings, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
