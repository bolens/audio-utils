# flac-to-mpc

FLAC → Musepack (`.mpc`) via **mpcenc** (`musepack-tools`). Default quality: **standard**.

Verify: duration ±50ms + stream probe. Requires `mpcenc` on `PATH`.

Core Vorbis comments (title, artist, album, album artist, date, track,
disc, genre, comment, composer) are copied to APEv2 tags via `mpcenc --tag`.
Embedded artwork is not carried over.

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> Musepack (.mpc) via mpcenc with duration verification.

Usage:
  flac-to-mpc.sh DIR [DIR ...]
  find-*-dirs.sh | flac-to-mpc.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE   telephone|radio|standard|extreme|insane|0-10
  -N / --no-resample
  Env: AUDIO_UTILS_MPC_QUALITY, FLAC2MPC_QUALITY

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
