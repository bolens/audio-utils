# flac-to-aac

FLAC → M4A (aac) with duration check. Default quality: **96** (speech/portable).
Music libraries: `-Q 192` or `AUDIO_UTILS_AAC_QUALITY=192`.

`-N` / `--no-resample` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

```bash
./flac-to-aac.sh -n DIR
./flac-to-aac.sh -Q 192 DIR
make help
```

## Profile selection

The default 96 kbps profile is intended for speech and compact portable copies,
not transparent music archiving. Music libraries should normally start at
`192`; supported CBR profiles range from `64` through `320` kbps. The output is
AAC in an `.m4a` container.

Unsupported rates or multichannel layouts may be resampled/downmixed by the
shared lossy preparation stage, with the change written to success notes.
`-N` rejects such files instead. Core tags and compatible artwork are copied
into the M4A container.

## Verification and safety

The result must probe as AAC and remain within about 50 ms of the prepared
input duration. Lossy output cannot PCM-MD5 match the FLAC, so existing sibling
checks are necessarily weaker than lossless conversion checks. Keep FLAC as
the archive source, and preview any `-d`/`-D` run.

Requires FFmpeg's native `aac` encoder. See
[lossy behavior](../../docs/lossy.md) and
[audiobook guidance](../../docs/audiobooks.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> m4a (aac) with verification.

Usage:
  flac-to-aac.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-aac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE
  -N / --no-resample   Fail instead of resampling/downmixing

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
