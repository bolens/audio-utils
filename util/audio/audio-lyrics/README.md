# audio-lyrics

Lyrics coverage across FLAC + lossy:

- default: report files with neither a `LYRICS` / `UNSYNCEDLYRICS` tag nor a
  `.lrc` / `.txt` sidecar
- `--import`: sidecar → `LYRICS` tag (FLAC via `metaflac`; other formats skip)
- `--export`: `LYRICS` tag → `<stem>.lrc` sidecar

`-y` overwrites an existing tag (import) or sidecar (export). No network —
lyric *fetching* is out of scope.

Part of **[audio-utils](../../../)**.

## Sidecar selection and mutation

Coverage treats either an embedded lyrics field or a same-stem `.lrc`/`.txt`
sidecar as present. Report mode changes nothing and makes gaps visible in batch
or CI-style audits.

Import is intentionally FLAC-only because `metaflac` provides a predictable
tag update path. Existing lyrics tags are retained unless `-y` is supplied.
Export writes the embedded text to a same-stem `.lrc`, also preserving an
existing sidecar unless `-y` is given.

```bash
./audio-lyrics.sh /path/to/library
./audio-lyrics.sh --export /path/to/library
./audio-lyrics.sh -n -y --import /path/to/flac-library
```

The tool does not validate LRC timestamps, reconcile conflicting tag/sidecar
text, or contact lyric services. It never deletes media and rejects `-d`/`-D`.

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
