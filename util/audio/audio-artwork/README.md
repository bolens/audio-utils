# audio-artwork

Embed folder covers into FLAC/MP3/Opus/M4A/… or extract to `cover.jpg`.

Part of **[audio-utils](../../../)**.

## Embed mode

The default mode searches each audio file's directory for the first sorted
`cover`, `folder`, or `front` image with a JPG, JPEG, or PNG extension. Files
that already contain artwork are skipped unless `-y` is supplied.

```bash
./audio-artwork.sh -n /path/to/library
./audio-artwork.sh /path/to/library
```

FLAC pictures are managed with `metaflac` when available. Other formats are
remuxed with FFmpeg using stream copy, so the audio is not re-encoded. Remuxed
files are prepared in a temporary sibling work directory before replacement.

## Extract mode

`-x` or `--extract` writes embedded artwork as `cover.jpg` in the album
directory. Because several tracks may target the same file, extraction is
locked per directory. Existing `cover.jpg` files are retained unless `-y` is
given. Sources without embedded pictures are reported as clean skips.

```bash
./audio-artwork.sh --extract /path/to/album
```

The tool never deletes audio and rejects `-d`/`-D`. Artwork changes alter the
container checksum but not the encoded audio stream. Requires
`ffmpeg`/`ffprobe`; `metaflac` is recommended for FLAC. See
[dependencies](../../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Embed or extract cover art for FLAC and common lossy formats.

Usage:
  audio-artwork.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -x / --extract   Export embedded picture to cover.jpg

-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
