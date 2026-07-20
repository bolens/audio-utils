# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Verified **audio conversion utilities** for Linux libraries. **FLAC** is the archive hub.

Docs: **[docs/](docs/)** — [requirements](docs/requirements.md) · [formats](docs/formats.md) · [cue](docs/cue.md) · [discs](docs/discs.md) · [streaming](docs/streaming.md) · [tak](docs/tak.md) · [dsd](docs/dsd.md) · [lossy](docs/lossy.md) · [playlists](docs/playlists.md) · [adding a util](docs/adding-a-util.md)

### Conversion

| Tool | Description |
|------|-------------|
| [`conversion/wav-to-flac/`](conversion/wav-to-flac/) / [`flac-to-wav/`](conversion/flac-to-wav/) | WAV ↔ FLAC |
| [`conversion/aiff-to-flac/`](conversion/aiff-to-flac/) / [`flac-to-aiff/`](conversion/flac-to-aiff/) | AIFF ↔ FLAC |
| [`conversion/wav-to-aiff/`](conversion/wav-to-aiff/) / [`aiff-to-wav/`](conversion/aiff-to-wav/) | WAV ↔ AIFF remux |
| [`conversion/caf-to-flac/`](conversion/caf-to-flac/) / [`flac-to-caf/`](conversion/flac-to-caf/) | CAF ↔ FLAC (PCM) |
| [`conversion/flac-to-alac/`](conversion/flac-to-alac/) / [`alac-to-flac/`](conversion/alac-to-flac/) | FLAC ↔ ALAC (`.m4a`) |
| [`conversion/flac-to-wv/`](conversion/flac-to-wv/) / [`wv-to-flac/`](conversion/wv-to-flac/) | FLAC ↔ WavPack |
| [`conversion/flac-to-ape/`](conversion/flac-to-ape/) / [`ape-to-flac/`](conversion/ape-to-flac/) | FLAC ↔ APE |
| [`conversion/flac-to-tak/`](conversion/flac-to-tak/) / [`tak-to-flac/`](conversion/tak-to-flac/) | FLAC ↔ TAK ([Takc](docs/tak.md)) |
| [`conversion/flac-to-tta/`](conversion/flac-to-tta/) / [`tta-to-flac/`](conversion/tta-to-flac/) | FLAC ↔ TTA |
| [`conversion/shn-to-flac/`](conversion/shn-to-flac/) | Shorten → FLAC (decode-only) |
| [`conversion/dsf-to-flac/`](conversion/dsf-to-flac/) | DSD (DSF/DFF) → FLAC ([dsd](docs/dsd.md)) |
| [`conversion/cue-to-flac/`](conversion/cue-to-flac/) | CUE + image → tracks |
| [`conversion/streams-to-flac/`](conversion/streams-to-flac/) | Multi-stream → `.aN.flac` |
| [`conversion/dvd-to-flac/`](conversion/dvd-to-flac/) / [`cdda-to-flac/`](conversion/cdda-to-flac/) | DVD VIDEO_TS / CDDA → FLAC |
| [`conversion/bluray-to-flac/`](conversion/bluray-to-flac/) | Blu-ray BDMV / decrypted M2TS\|MKV → FLAC ([discs](docs/discs.md)) |
| [`conversion/flac-to-mp3/`](conversion/flac-to-mp3/) | FLAC → MP3 (default **v0**) |
| [`conversion/flac-to-opus/`](conversion/flac-to-opus/) / [`flac-to-aac/`](conversion/flac-to-aac/) / [`flac-to-vorbis/`](conversion/flac-to-vorbis/) | FLAC → Opus / AAC / Vorbis |
| [`conversion/flac-to-wma/`](conversion/flac-to-wma/) / [`flac-to-speex/`](conversion/flac-to-speex/) / [`flac-to-mpc/`](conversion/flac-to-mpc/) | FLAC → WMA / Speex / Musepack |
| [`conversion/lossy-to-flac/`](conversion/lossy-to-flac/) | Lossy → FLAC (normalize; does not restore quality) |

### Util

| Tool | Description |
|------|-------------|
| [`util/flac-verify/`](util/flac-verify/) | FLAC integrity (`flac -t`; optional decode MD5) |
| [`util/flac-replaygain/`](util/flac-replaygain/) | ReplayGain 2.0 tags (album+track via rsgain/loudgain) |
| [`util/flac-artwork/`](util/flac-artwork/) | Embed / extract cover art |
| [`util/flac-audit/`](util/flac-audit/) | Library audit (integrity, tags, cover, leftover PCM) |
| [`util/flac-authenticity/`](util/flac-authenticity/) | Detect fake lossless / upsampled “hi-res” / padded 16→24 |
| [`util/flac-tags/`](util/flac-tags/) | Normalize tags (case, track/date, strip junk) |
| [`util/flac-dupes/`](util/flac-dupes/) | Content duplicates (STREAMINFO MD5 / decode / fingerprint) |
| [`util/flac-optimize/`](util/flac-optimize/) | Recompress FLAC (bit-identical PCM) |
| [`util/flac-rename/`](util/flac-rename/) | Rename / layout from tags |
| [`util/flac-cue-export/`](util/flac-cue-export/) | Album tracks → image FLAC + CUE |
| [`util/flac-strip/`](util/flac-strip/) | Strip padding / APPLICATION; optional core-tags-only |
| [`util/flac-inventory/`](util/flac-inventory/) | Library inventory report (rate/depth/RG/art/size) |
| [`util/audio-replaygain/`](util/audio-replaygain/) | ReplayGain for FLAC + lossy (rsgain/loudgain) |
| [`util/audio-tags/`](util/audio-tags/) | Normalize tags across FLAC + lossy |
| [`util/audio-dupes/`](util/audio-dupes/) | Cross-format duplicates (chromaprint / MD5) |
| [`util/audio-artwork/`](util/audio-artwork/) | Embed / extract covers (multi-format) |
| [`util/library-sync/`](util/library-sync/) | FLAC ↔ portable sibling presence check |
| [`util/tree-diff/`](util/tree-diff/) | Compare library tree vs backup (`--against`) |
| [`util/hash-verify/`](util/hash-verify/) | Sidecar `.sha256` / `.md5` verify or write |
| [`util/pcm-cleanup/`](util/pcm-cleanup/) | Leftover WAV/AIFF/CAF beside verified FLAC |
| [`util/cue-audit/`](util/cue-audit/) | CUE health (image, tracks, UTF-8) |
| [`util/silence-detect/`](util/silence-detect/) | Leading/trailing silence + clipping QC |
| [`util/disc-inventory/`](util/disc-inventory/) | Catalog VIDEO_TS / BDMV / CUE units |
| [`util/lossy-audit/`](util/lossy-audit/) | Portable lossy audit (tags, cover, bitrate) |
| [`util/playlist-audit/`](util/playlist-audit/) | Playlist health (paths, empty, dupes, UTF-8) |
| [`util/playlist-normalize/`](util/playlist-normalize/) | Rewrite format / relative↔absolute paths |
| [`util/playlist-generate/`](util/playlist-generate/) | Build `.m3u` per audio directory |
| [`util/playlist-dedupe/`](util/playlist-dedupe/) | Drop duplicate songs from playlists |

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
