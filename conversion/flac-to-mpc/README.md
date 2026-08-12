# flac-to-mpc

FLAC → Musepack (`.mpc`) via **mpcenc** (`musepack-tools`). Default quality: **standard**.

Verify: duration ±50ms + stream probe. Requires `mpcenc` on `PATH`.

Core Vorbis comments (title, artist, album, album artist, date, track,
disc, genre, comment, composer) are copied to APEv2 tags via `mpcenc --tag`.
Embedded artwork is not carried over.

Part of **[audio-utils](../../)**.

## Quality and preparation

Named profiles map to `mpcenc --quality`: `telephone` (2), `radio` (4),
`standard` (5), `extreme` (6), and `insane` (7). Numeric values from 0 through
10, including decimals such as `5.5`, are also accepted.

```bash
./flac-to-mpc.sh -n -Q standard /path/to/album
./flac-to-mpc.sh -Q extreme /path/to/album
```

Input outside Musepack's supported rate/channel shape may be prepared through
the shared resample/downmix path; `-N` rejects instead. Core tags are passed to
APEv2 through `mpcenc`, but embedded artwork is not transferred.

## Verification and deletion

`mpcdec` and `ffprobe` must read the result, and duration must remain within
approximately 50 ms. As with every lossy encoder, this cannot prove PCM
identity, and an existing sibling is accepted at probe strength only. Keep the
FLAC archive or explicitly accept that limitation before using `-d`/`-D`.

Requires both `mpcenc` and `mpcdec` from `musepack-tools`, plus the core FLAC
and FFmpeg tools. See [lossy behavior](../../docs/lossy.md) and
[dependencies](../../docs/requirements.md).

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
