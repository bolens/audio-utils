# flac-to-tak

FLAC → TAK via Takc; verify by decode MD5. Default preset p2.

Limitation: `Takc` writes no tags, so Vorbis comments and artwork are not
carried into the `.tak` output. When the source has tags, the success log
notes column records `tags=dropped`. Re-tag with an APEv2 tagger if needed.

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> TAK via Takc with MD5 verification.

Usage:
  flac-to-tak.sh DIR [DIR ...]
  find-*-dirs.sh | flac-to-tak.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PRESET / --quality PRESET   TAK preset p0-p5[em] (default p2)
  Env: AUDIO_UTILS_TAK_PRESET, AUDIO_UTILS_TAKC

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
