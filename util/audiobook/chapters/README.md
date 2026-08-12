# chapters

List / extract / embed chapter markers on `.m4b` / `.m4a` (ffmpeg ffmetadata).
Default: list chapters. `--extract=FILE` writes ffmetadata; `--embed=FILE`
with `--apply` (or `-y`) rewrites the container.

Rejects `-d`/`-D`. Peer of [`tracks-to-m4b`](../../../conversion/tracks-to-m4b/)
and [`m4b-to-tracks`](../../../conversion/m4b-to-tracks/). See [audiobooks](../../../docs/audiobooks.md).

Part of **[audio-utils](../../../)**.

```bash
./chapters.sh -n DIR
./chapters.sh --extract=chapters.txt DIR
./chapters.sh --embed=chapters.txt --apply DIR
make help
```

## Editing workflow

List mode is safest for inspection. Extract mode writes FFmetadata chapter
syntax to the requested file; edit timestamps and titles there, keeping ranges
ordered and valid for the media duration.

Embed mode requires `--apply` (or its supported `-y` alias), remuxes into a
temporary container with the replacement chapter table, and only then replaces
the source. Audio streams are copied rather than re-encoded. A missing or
invalid chapter file fails before a successful replacement is reported.

Keep a backup when editing irreplaceable M4B metadata: container-specific fields
outside the chapter table may not survive every remux. The tool does not infer
chapters from silence and rejects source deletion. See
[audiobook workflows](../../../docs/audiobooks.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
chapters - list / extract / embed chapter markers on .m4b / .m4a.

Usage:
  chapters.sh DIR [DIR ...]
  find-m4b-dirs.sh | chapters.sh

Options:
  --extract=FILE   Write ffmetadata chapters to FILE
  --embed=FILE     Apply ffmetadata from FILE (requires --apply or -y)
  --apply          Allow --embed to rewrite the container
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

-d / -D rejected. Default: list chapters.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
