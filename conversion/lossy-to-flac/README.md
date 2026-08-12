# lossy-to-flac

Decode lossy audio (MP3 / AAC / Opus / Vorbis / Speex / WMA / MPC) → FLAC for library
normalization. **Does not restore lost quality** — the FLAC wraps decoded PCM.

Skips ALAC-in-`.m4a` (use [`alac-to-flac`](../alac-to-flac/)).

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Decode lossy audio -> FLAC for library normalization (does not restore quality).

Usage:
  lossy-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | lossy-to-flac.sh

Accepts: .mp3 .m4a .aac .opus .ogg .oga .wma .mpc .spx (codec-gated; skips ALAC .m4a)

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
