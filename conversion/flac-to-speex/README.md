# flac-to-speex

FLAC → Speex (`.spx`, libspeex) with duration check. Default quality: **q6**.

Speech-oriented; for music prefer Opus/MP3. `-N` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> Speex (.spx) with verification.

Usage:
  flac-to-speex.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-speex.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE
  -N / --no-resample   Fail instead of resampling/downmixing

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
