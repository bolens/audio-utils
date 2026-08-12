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
