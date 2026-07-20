# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Verified **audio conversion utilities** for Linux libraries. **FLAC** is the archive hub.

Docs: **[docs/](docs/)** — [requirements](docs/requirements.md) · [formats](docs/formats.md) · [cue](docs/cue.md) · [discs](docs/discs.md) · [streaming](docs/streaming.md) · [tak](docs/tak.md) · [lossy](docs/lossy.md) · [adding a util](docs/adding-a-util.md)

### Conversion

| Tool | Description |
|------|-------------|
| [`conversion/wav-to-flac/`](conversion/wav-to-flac/) / [`flac-to-wav/`](conversion/flac-to-wav/) | WAV ↔ FLAC |
| [`conversion/aiff-to-flac/`](conversion/aiff-to-flac/) / [`flac-to-aiff/`](conversion/flac-to-aiff/) | AIFF ↔ FLAC |
| [`conversion/wav-to-aiff/`](conversion/wav-to-aiff/) / [`aiff-to-wav/`](conversion/aiff-to-wav/) | WAV ↔ AIFF remux |
| [`conversion/flac-to-alac/`](conversion/flac-to-alac/) / [`alac-to-flac/`](conversion/alac-to-flac/) | FLAC ↔ ALAC (`.m4a`) |
| [`conversion/flac-to-wv/`](conversion/flac-to-wv/) / [`wv-to-flac/`](conversion/wv-to-flac/) | FLAC ↔ WavPack |
| [`conversion/flac-to-ape/`](conversion/flac-to-ape/) / [`ape-to-flac/`](conversion/ape-to-flac/) | FLAC ↔ APE |
| [`conversion/flac-to-tak/`](conversion/flac-to-tak/) / [`tak-to-flac/`](conversion/tak-to-flac/) | FLAC ↔ TAK ([Takc](docs/tak.md)) |
| [`conversion/cue-to-flac/`](conversion/cue-to-flac/) | CUE + image → tracks |
| [`conversion/streams-to-flac/`](conversion/streams-to-flac/) | Multi-stream → `.aN.flac` |
| [`conversion/dvd-to-flac/`](conversion/dvd-to-flac/) / [`cdda-to-flac/`](conversion/cdda-to-flac/) | DVD VIDEO_TS / CDDA → FLAC |
| [`conversion/bluray-to-flac/`](conversion/bluray-to-flac/) | Blu-ray BDMV / decrypted M2TS\|MKV → FLAC ([discs](docs/discs.md)) |
| [`conversion/flac-to-mp3/`](conversion/flac-to-mp3/) | FLAC → MP3 (default **v0**) |
| [`conversion/flac-to-opus/`](conversion/flac-to-opus/) / [`flac-to-aac/`](conversion/flac-to-aac/) / [`flac-to-vorbis/`](conversion/flac-to-vorbis/) | FLAC → Opus / AAC / Vorbis |

### Util

| Tool | Description |
|------|-------------|
| [`util/flac-verify/`](util/flac-verify/) | FLAC integrity (`flac -t`; optional decode MD5) |
| [`util/flac-replaygain/`](util/flac-replaygain/) | ReplayGain 2.0 tags (album+track via rsgain/loudgain) |
| [`util/flac-artwork/`](util/flac-artwork/) | Embed / extract cover art |
| [`util/flac-audit/`](util/flac-audit/) | Library audit (integrity, tags, cover, leftover PCM) |
| [`util/flac-authenticity/`](util/flac-authenticity/) | Detect fake lossless / upsampled “hi-res” / padded 16→24 |

## Quick start

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config"
# edit AUDIO_UTILS_ROOTS — see docs/requirements.md

make check
make -C conversion/wav-to-flac convert-quiet
make -C conversion/flac-to-mp3 convert-quiet
make -C util/flac-verify convert-quiet
```

## Layout

```
audio-utils/
  docs/                 # requirements, formats, discs, streaming, tak, lossy, …
  lib/                  # shared cli, plugin_init, driver, pipelines, …
  conversion/<tool>/    # format converters (FLAC hub)
  util/<tool>/          # library lifecycle (verify, RG, artwork, audit)
```

Plugin contract: [docs/adding-a-converter.md](docs/adding-a-converter.md). Util contract: [docs/adding-a-util.md](docs/adding-a-util.md).

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
