# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Verified **audio conversion utilities** for Linux libraries. **FLAC** is the archive hub.

Docs: **[docs/](docs/)** — [requirements](docs/requirements.md) · [formats](docs/formats.md) · [cue](docs/cue.md) · [discs](docs/discs.md) · [tak](docs/tak.md) · [lossy](docs/lossy.md)

| Tool | Description |
|------|-------------|
| [`wav-to-flac/`](wav-to-flac/) / [`flac-to-wav/`](flac-to-wav/) | WAV ↔ FLAC |
| [`aiff-to-flac/`](aiff-to-flac/) / [`flac-to-aiff/`](flac-to-aiff/) | AIFF ↔ FLAC |
| [`wav-to-aiff/`](wav-to-aiff/) / [`aiff-to-wav/`](aiff-to-wav/) | WAV ↔ AIFF remux |
| [`flac-to-alac/`](flac-to-alac/) / [`alac-to-flac/`](alac-to-flac/) | FLAC ↔ ALAC (`.m4a`) |
| [`flac-to-wv/`](flac-to-wv/) / [`wv-to-flac/`](wv-to-flac/) | FLAC ↔ WavPack |
| [`flac-to-ape/`](flac-to-ape/) / [`ape-to-flac/`](ape-to-flac/) | FLAC ↔ APE |
| [`flac-to-tak/`](flac-to-tak/) / [`tak-to-flac/`](tak-to-flac/) | FLAC ↔ TAK ([Takc](docs/tak.md)) |
| [`cue-to-flac/`](cue-to-flac/) | CUE + image → tracks |
| [`streams-to-flac/`](streams-to-flac/) | Multi-stream → `.aN.flac` |
| [`dvd-to-flac/`](dvd-to-flac/) / [`cdda-to-flac/`](cdda-to-flac/) | DVD VIDEO_TS / CDDA → FLAC |
| [`flac-to-mp3/`](flac-to-mp3/) | FLAC → MP3 (default **v0**) |
| [`flac-to-opus/`](flac-to-opus/) / [`flac-to-aac/`](flac-to-aac/) / [`flac-to-vorbis/`](flac-to-vorbis/) | FLAC → Opus / AAC / Vorbis |

## Quick start

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config"
# edit AUDIO_UTILS_ROOTS — see docs/requirements.md

make check
make -C wav-to-flac convert-quiet
make -C flac-to-mp3 convert-quiet
```

## Layout

```
audio-utils/
  docs/           # requirements, formats, discs, tak, lossy, …
  lib/            # driver, worker, pcm_flac, cue, lossy, tak, dvd, cdda
  <tool>/         # thin CLI + lib/plugin.sh
```

Plugin contract: [docs/adding-a-converter.md](docs/adding-a-converter.md).

### Paths (XDG)

| Data | Default |
|------|---------|
| Config | `$XDG_CONFIG_HOME/audio-utils/config` |
| Logs | `$XDG_STATE_HOME/audio-utils/<tool>/` |
| Runtime | `$XDG_RUNTIME_DIR/audio-utils/` |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Conversion/preflight failures |
| 2 | Usage / deps / bad arguments |

## License

[MIT](LICENSE)
