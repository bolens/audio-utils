# playlist-export

Materialize M3U / PLS / XSPF playlists onto a device: copy every referenced
file into `--dest/<playlist>/` and write a rewritten relative `.m3u` beside
them. `--number` prefixes files with a 3-digit play order for players that
sort by name. Same-size files already at the destination are skipped
(resumable); `-y` forces overwrite.

Copies as-is — transcode first with the `conversion/flac-to-*` tools if the
device needs lossy.

Part of **[audio-utils](../../../)**.
