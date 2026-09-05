# shn-to-flac

Shorten (.shn) → FLAC with PCM MD5 verify. Decode-only (no Shorten encoder in ffmpeg).

Part of **[audio-utils](../../)**.

## Intended use

Shorten commonly appears in older live-music archives. This converter is a
one-way archival migration: FFmpeg supplies a decoder, but there is no matching
Shorten encoder in this toolkit.

```bash
./shn-to-flac.sh -n /path/to/show
./shn-to-flac.sh /path/to/show
```

The source is decoded and encoded to a temporary FLAC. The output must pass
`flac -t`, decode cleanly, and match the source PCM MD5 before it is installed
atomically. Existing FLAC siblings are accepted only after the same comparison.

## Safety and caveats

`-d` and cleanup-only `-D` are guarded by verified audio identity; preview them
with `-n`. Some historical SHN sets depend on external metadata or checksum
files. Those sidecars are not consumed or deleted, so retain them when they
form part of the release provenance.

Requires an FFmpeg build with Shorten decoding, plus `ffprobe`, `flac`, and
`metaflac`. See [dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert Shorten (.shn) -> FLAC with PCM audio-MD5 verification.

Usage:
  shn-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | shn-to-flac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
