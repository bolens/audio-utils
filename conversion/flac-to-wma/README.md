# flac-to-wma

FLAC → WMA (wmav2) with duration check. Default quality: **192**.

`-N` / `--no-resample` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

## Compatibility use

WMA v2 is mainly for older Windows, automotive, or hardware ecosystems.
Available CBR profiles are `128`, `160`, `192`, and `256` kbps, with `192` as
the default. Prefer a modern codec when WMA compatibility is not required.

```bash
./flac-to-wma.sh -n -Q 192 /path/to/album
./flac-to-wma.sh -Q 256 /path/to/album
```

Unsupported channel layouts or rates are prepared by resampling/downmixing and
noted in the success log; `-N` refuses those changes. WMA/ASF metadata does not
map perfectly from FLAC, so review custom tags and artwork.

Verification requires a readable WMA stream and duration within roughly 50 ms,
not decoded PCM equality. Existing outputs receive only that lossy check.
Retain FLAC as the master and be conservative with `-d`/`-D`; use `-n` first.
Requires FFmpeg's `wmav2` encoder. See
[lossy behavior](../../docs/lossy.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> WMA (wmav2) with verification.

Usage:
  flac-to-wma.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-wma.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE
  -N / --no-resample   Fail instead of resampling/downmixing

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
