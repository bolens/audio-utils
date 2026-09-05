# audio-tags

Normalize core tags across FLAC and common lossy formats. FLAC uses `metaflac`;
others remux with `ffmpeg -c copy`.

Part of **[audio-utils](../../../)**.

## Normalizations

The tool normalizes track numbers (including `N/TOTAL` forms), reduces ISO-like
dates to their date/year representation, and uses consistent core tag names.
`-A` / `--fill-albumartist` copies `ARTIST` into a missing album-artist field.
For FLAC it also removes common provenance-noise tags such as `ITUNNORM`,
`ITUNSMPB`, `ENCODER`, and `TOOL`.

```bash
./audio-tags.sh -n /path/to/library
./audio-tags.sh --fill-albumartist /path/to/library
```

## Mutation model

FLAC is edited with `metaflac`. Other supported formats are remuxed with
`ffmpeg -c copy` into temporary storage and then replaced, so audio is not
re-encoded. The container hash will change even when its encoded audio does
not. Use `-n` to inventory the scope before a large normalization run.

This is an in-place metadata operation and does not create disposable source
siblings; `-d` and `-D` are rejected. Back up irreplaceable custom metadata
before broad normalization because only the documented core fields are
rewritten for non-FLAC containers. Requires `ffmpeg`/`ffprobe`, with `metaflac`
for FLAC. See [dependencies](../../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Normalize tags across FLAC and common lossy formats.

Usage:
  audio-tags.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -A / --fill-albumartist   Set album artist from artist when missing

FLAC uses metaflac; other formats remux with ffmpeg -c copy.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
