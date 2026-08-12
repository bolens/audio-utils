# flac-to-wv

Verified FLAC → WavPack (`.wv`). Hybrid (`.wvc` companion) is rejected.

## Scope

This creates pure lossless WavPack files beside FLAC sources. It intentionally
does not create or accept hybrid lossy-plus-correction pairs: a `.wvc`
companion makes the candidate unsuitable for this workflow.

```bash
./flac-to-wv.sh -n /path/to/album
./flac-to-wv.sh /path/to/album
```

## Verification and deletion safety

Each source FLAC is tested, encoded through FFmpeg's `wavpack` encoder, decoded
again, and compared to the source by PCM MD5. The output must also probe as a
pure WavPack stream before atomic installation. Existing siblings are skipped
only after the same codec and audio-identity checks.

`-d` deletes a FLAC only after successful verified conversion. `-D` deletes
sources only when an already-existing pure `.wv` sibling matches. Always use
`-n` to inspect a cleanup run first.

## Requirements

Requires `ffmpeg` with the `wavpack` encoder, `ffprobe`, `flac`, and `flock`.
See [format verification](../../docs/formats.md) and
[dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> WavPack (.wv) with PCM audio-MD5 verification.

Usage:
  flac-to-wv.sh DIR [DIR ...]

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
