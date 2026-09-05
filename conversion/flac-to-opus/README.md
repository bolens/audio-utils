# flac-to-opus

FLAC → OPUS (libopus) with duration check. Default quality: **128**.

`-N` / `--no-resample` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

## Choosing a profile

Opus is a strong choice for modern portable playback and speech. Profiles are
CBR targets from `64` through `256` kbps; `128` is the general default, while
`64`/`96` suit speech and `160`/`192` give music more headroom.

```bash
./flac-to-opus.sh -n -Q 128 /path/to/album
./flac-to-opus.sh -Q 192 /path/to/album
```

## Preparation and verification

Unsupported sample rates and channel layouts are resampled or downmixed by the
shared lossy pipeline and recorded in the success notes. Use `-N` when that
would be unacceptable. Tags and cover art are copied where Opus/Ogg supports
them.

Lossy output cannot match the FLAC PCM MD5. Verification instead requires a
readable Opus stream and duration within approximately 50 ms. Existing outputs
are therefore probe-checked, not proven to contain equivalent audio. Treat
`-d`/`-D` as portable-library cleanup, not archival verification, and preview
with `-n`. Requires FFmpeg with `libopus`; see
[lossy behavior](../../docs/lossy.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> opus (libopus) with verification.

Usage:
  flac-to-opus.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-opus.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE
  -N / --no-resample   Fail instead of resampling/downmixing

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
