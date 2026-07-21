# audio-lyrics

Lyrics coverage across FLAC + lossy:

- default: report files with neither a `LYRICS` / `UNSYNCEDLYRICS` tag nor a
  `.lrc` / `.txt` sidecar
- `--import`: sidecar → `LYRICS` tag (FLAC via `metaflac`; other formats skip)
- `--export`: `LYRICS` tag → `<stem>.lrc` sidecar

`-y` overwrites an existing tag (import) or sidecar (export). No network —
lyric *fetching* is out of scope.

Part of **[audio-utils](../../../)**.
