# flac-to-vorbis

FLAC → OGG (libvorbis) with duration check. Default quality: **q6**.

`-N` / `--no-resample` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

## Choosing a profile

Vorbis profiles range from `q4` through `q8`; `q6` is the balanced default.
Vorbis remains useful for broad Ogg-compatible software, though Opus is usually
preferred for new low-bitrate libraries.

```bash
./flac-to-vorbis.sh -n -Q q6 /path/to/album
./flac-to-vorbis.sh -Q q8 /path/to/album
```

The shared lossy preparation stage may resample unsupported rates or downmix
channel layouts and records those changes. `-N` makes either requirement fail
closed. Core tags and compatible artwork are copied.

Verification is a successful Vorbis probe plus duration within roughly 50 ms;
lossy PCM cannot equal the source MD5. Existing `.ogg` files receive the same
probe-level check, so source deletion is weaker than lossless sibling cleanup.
Keep FLAC as the archive master and use `-n` before `-d`/`-D`. Requires FFmpeg
with `libvorbis`; see [lossy behavior](../../docs/lossy.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> ogg (libvorbis) with verification.

Usage:
  flac-to-vorbis.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-vorbis.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE
  -N / --no-resample   Fail instead of resampling/downmixing

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
