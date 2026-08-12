# playlist-export

Materialize M3U / PLS / XSPF playlists onto a device: copy every referenced
file into `--dest/<playlist>/` and write a rewritten relative `.m3u` beside
them. `--number` prefixes files with a 3-digit play order for players that
sort by name. Same-size files already at the destination are skipped
(resumable); `-y` forces overwrite.

Copies as-is — transcode first with the `conversion/flac-to-*` tools if the
device needs lossy.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Materialize playlists onto a device: copy referenced files + rewritten .m3u.

Usage:
  playlist-export.sh --dest DIR PLAYLIST_DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --dest=DIR      Destination root (required); one subdirectory per playlist
  --number        Prefix copied files with a 3-digit play order
  -y              Overwrite existing files at the destination

-d / -D rejected. Existing same-size destination files are skipped.
Exit codes: 0 ok, 1 failures/missing entries, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
