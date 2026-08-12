# audio-lyrics

Lyrics coverage across FLAC + lossy:

- default: report files with neither a `LYRICS` / `UNSYNCEDLYRICS` tag nor a
  `.lrc` / `.txt` sidecar
- `--import`: sidecar → `LYRICS` tag (FLAC via `metaflac`; other formats skip)
- `--export`: `LYRICS` tag → `<stem>.lrc` sidecar

`-y` overwrites an existing tag (import) or sidecar (export). No network —
lyric *fetching* is out of scope.

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Lyrics audit / sidecar sync: LYRICS tag vs .lrc / .txt sidecars.

Usage:
  audio-lyrics.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --import        Import sidecar .lrc/.txt into the LYRICS tag (FLAC only)
  --export        Write <stem>.lrc sidecar from the LYRICS tag
  -y              Overwrite existing tag (--import) or sidecar (--export)

Default mode reports files with neither tag nor sidecar. -d / -D rejected.
Exit codes: 0 ok/clean, 1 missing/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
