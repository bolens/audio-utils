# wv-to-flac

Pure WavPack `.wv` → FLAC. Hybrid (`.wvc` companion) skipped via `plugin_accept_source`.

## Scope

Use this to normalize pure lossless WavPack archives into FLAC. Hybrid WavPack
is deliberately excluded because decoding without its correction file may be
lossy; files with a `.wvc` companion are skipped rather than silently treated
as equivalent sources.

```bash
./wv-to-flac.sh -n /path/to/album
./wv-to-flac.sh /path/to/album
```

## Verification and existing outputs

The source and temporary FLAC are independently decoded and compared by PCM
MD5, and the FLAC must pass `flac -t` before atomic installation. Tags and
artwork are copied where the formats support them. A sibling FLAC is skipped
only when it is valid and contains the same decoded audio.

`-d` and cleanup-only `-D` are guarded by those verification checks. They do
not provide a way to dispose of hybrid pairs; handle those separately with a
decoder that explicitly uses the `.wvc` correction data.

## Requirements

Requires FFmpeg WavPack decoding, `ffprobe`, `flac`, and `metaflac`. See
[format verification](../../docs/formats.md) and
[dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert pure WavPack (.wv) -> FLAC. Hybrid (.wvc) rejected.

Usage:
  wv-to-flac.sh DIR [DIR ...]

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
