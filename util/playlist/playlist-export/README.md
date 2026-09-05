# playlist-export

Materialize M3U / PLS / XSPF playlists onto a device: copy every referenced
file into `--dest/<playlist>/` and write a rewritten relative `.m3u` beside
them. `--number` prefixes files with a 3-digit play order for players that
sort by name. Same-size files already at the destination are skipped
(resumable); `-y` forces overwrite.

Copies as-is — transcode first with the `conversion/flac-to-*` tools if the
device needs lossy.

Part of **[audio-utils](../../../)**.

## Destination layout and collisions

A playlist named `Road Trip.m3u` exports beneath
`--dest/Road Trip/`, with `Road Trip.m3u` rewritten to relative paths inside
that directory. `--number` prefixes copied basenames with `001 -`, `002 -`, and
so on in playlist order.

```bash
./playlist-export.sh -n --dest /media/player /path/to/playlists
./playlist-export.sh --number --dest /media/player /path/to/playlists
```

Same-size existing targets are treated as resumable matches; this is a speed
heuristic, not a checksum comparison. A different-size basename is uniquified
with ` (N)` unless `-y` requests replacement. Missing source entries are
reported, the usable subset may still be copied, and the run exits with a
finding rather than claiming a complete export.

Files are copied byte-for-byte with metadata where `cp -p` permits. No audio is
transcoded or deleted, and `-d`/`-D` are rejected. Audit playlists before a
large device export and safely unmount removable media afterward.

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
