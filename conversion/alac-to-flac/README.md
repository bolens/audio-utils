# alac-to-flac

ALAC `.m4a` → FLAC. AAC/other codecs in `.m4a` are skipped via `plugin_accept_source`.

## When to use it

Use this when migrating an Apple-oriented lossless library into the FLAC
archive hub. File extension alone is not trusted: each `.m4a` is probed and is
accepted only when its audio codec is ALAC, so AAC files mixed into the same
tree are left untouched.

```bash
./alac-to-flac.sh -n /path/to/album
./alac-to-flac.sh /path/to/album
```

## Verification and existing files

The source is decoded, encoded to a temporary FLAC, tested with `flac -t`, and
compared by decoded PCM MD5 before the output is installed atomically beside
the `.m4a`. Metadata and embedded artwork are copied where supported. An
existing sibling is skipped only when it is a valid FLAC whose decoded audio
matches the ALAC source.

`-d` removes an ALAC source only after that verified conversion succeeds. `-D`
is cleanup-only and applies the same strong sibling check. Preview either mode
with `-n`; do not use deletion flags until the reported paths are correct.

## Requirements and limits

Requires `ffmpeg`/`ffprobe` with ALAC decoding plus `flac` and `metaflac`.
Container-only metadata that has no Vorbis-comment or FLAC-picture equivalent
may not round-trip. See [format verification](../../docs/formats.md) and
[dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert ALAC (.m4a) -> FLAC. Non-ALAC m4a files are skipped.

Usage:
  alac-to-flac.sh DIR [DIR ...]
  find-m4a-dirs.sh | alac-to-flac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
