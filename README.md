# audio-utils

[![CI](https://github.com/bolens/audio-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/bolens/audio-utils/actions/workflows/ci.yml)

Verified **audio conversion utilities** for Linux libraries (GNU userland; bash 4.3+). **FLAC** is the archive hub. Not macOS, BSD, BusyBox, or Alpine — see [requirements](docs/requirements.md).

Docs: **[docs/](docs/)** — [requirements](docs/requirements.md) · [formats](docs/formats.md) · [cue](docs/cue.md) · [discs](docs/discs.md) · [streaming](docs/streaming.md) · [tak](docs/tak.md) · [dsd](docs/dsd.md) · [lossy](docs/lossy.md) · [playlists](docs/playlists.md) · [enrichment](docs/enrichment.md) · [adding a converter](docs/adding-a-converter.md) · [adding a util](docs/adding-a-util.md)

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

Utils are grouped by category: `util/<category>/<tool>/`.

#### `util/flac/` — FLAC library maintenance

| Tool | Description |
|------|-------------|
| [`flac-verify/`](util/flac/flac-verify/) | FLAC integrity (`flac -t`; optional decode MD5) |
| [`flac-replaygain/`](util/flac/flac-replaygain/) | ReplayGain 2.0 tags (album+track via rsgain/loudgain) |
| [`flac-artwork/`](util/flac/flac-artwork/) | Embed / extract cover art |
| [`flac-audit/`](util/flac/flac-audit/) | Library audit (integrity, tags, cover, leftover PCM) |
| [`flac-authenticity/`](util/flac/flac-authenticity/) | Detect fake lossless / upsampled “hi-res” / padded 16→24 |
| [`flac-tags/`](util/flac/flac-tags/) | Normalize tags (case, track/date, strip junk) |
| [`flac-dupes/`](util/flac/flac-dupes/) | Content duplicates (STREAMINFO MD5 / decode / fingerprint) |
| [`flac-optimize/`](util/flac/flac-optimize/) | Recompress FLAC (bit-identical PCM) |
| [`flac-rename/`](util/flac/flac-rename/) | Rename / layout from tags |
| [`flac-cue-export/`](util/flac/flac-cue-export/) | Album tracks → image FLAC + CUE |
| [`flac-strip/`](util/flac/flac-strip/) | Strip padding / APPLICATION; optional core-tags-only |
| [`flac-inventory/`](util/flac/flac-inventory/) | Library inventory report (rate/depth/RG/art/size) |

#### `util/audio/` — multi-format tools

| Tool | Description |
|------|-------------|
| [`audio-replaygain/`](util/audio/audio-replaygain/) | ReplayGain for FLAC + lossy (rsgain/loudgain) |
| [`audio-tags/`](util/audio/audio-tags/) | Normalize tags across FLAC + lossy |
| [`audio-bpm/`](util/audio/audio-bpm/) | Detect + tag tempo (BPM via bpm-tools or aubio) |
| [`audio-key/`](util/audio/audio-key/) | Detect + tag musical key (INITIALKEY via keyfinder-cli) |
| [`audio-dupes/`](util/audio/audio-dupes/) | Cross-format duplicates (chromaprint / MD5) |
| [`audio-artwork/`](util/audio/audio-artwork/) | Embed / extract covers (multi-format) |
| [`audio-lyrics/`](util/audio/audio-lyrics/) | Lyrics audit; sidecar `.lrc` import / export |
| [`tags-lookup/`](util/audio/tags-lookup/) | AcoustID → MusicBrainz MBID report ([opt-in network](docs/enrichment.md)) |

#### `util/playlist/` — playlists

| Tool | Description |
|------|-------------|
| [`playlist-audit/`](util/playlist/playlist-audit/) | Playlist health (paths, empty, dupes, UTF-8) |
| [`playlist-normalize/`](util/playlist/playlist-normalize/) | Rewrite format / relative↔absolute paths |
| [`playlist-generate/`](util/playlist/playlist-generate/) | Build `.m3u` per audio directory |
| [`playlist-dedupe/`](util/playlist/playlist-dedupe/) | Drop duplicate songs from playlists |
| [`playlist-export/`](util/playlist/playlist-export/) | Copy playlist contents + rewritten `.m3u` to a device |

#### `util/audit/` — audits and reports

| Tool | Description |
|------|-------------|
| [`album-audit/`](util/audit/album-audit/) | Album-level audit (track gaps, mixed tags/rate/depth) |
| [`cue-audit/`](util/audit/cue-audit/) | CUE health (image, tracks, UTF-8) |
| [`gapless-audit/`](util/audit/gapless-audit/) | Gapless metadata (MP3 LAME header, M4A `iTunSMPB`) |
| [`lossy-audit/`](util/audit/lossy-audit/) | Portable lossy audit (tags, cover, bitrate) |
| [`path-audit/`](util/audit/path-audit/) | Filename portability audit (FAT/NTFS chars, length, UTF-8) |
| [`disc-inventory/`](util/audit/disc-inventory/) | Catalog VIDEO_TS / BDMV / CUE units |
| [`silence-detect/`](util/audit/silence-detect/) | Leading/trailing silence + clipping QC |
| [`dynamics-report/`](util/audit/dynamics-report/) | EBU R128 loudness / LRA / true-peak survey |
| [`spectrogram-export/`](util/audit/spectrogram-export/) | Batch spectrogram PNGs (sox / ffmpeg) |

#### `util/library/` — library and filesystem hygiene

| Tool | Description |
|------|-------------|
| [`library-sync/`](util/library/library-sync/) | FLAC ↔ portable sibling presence check |
| [`library-prune/`](util/library/library-prune/) | Orphaned portable files without a FLAC master |
| [`tree-diff/`](util/library/tree-diff/) | Compare library tree vs backup (`--against`) |
| [`hash-verify/`](util/library/hash-verify/) | Sidecar `.sha256` / `.md5` verify or write |
| [`pcm-cleanup/`](util/library/pcm-cleanup/) | Leftover WAV/AIFF/CAF beside verified FLAC |
| [`junk-cleanup/`](util/library/junk-cleanup/) | Thumbs.db / .DS_Store / AppleDouble / zero-byte files |
| [`perms-normalize/`](util/library/perms-normalize/) | Permission modes report / `--apply` (644 / 755) |

## Quick start

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config"
# edit AUDIO_UTILS_ROOTS — see docs/requirements.md

make check
make -C conversion/wav-to-flac convert-quiet
make -C conversion/flac-to-mp3 convert-quiet
make -C util/flac/flac-verify convert-quiet
make flac-verify-convert-quiet   # short alias for any tool
```

## Layout

```
audio-utils/
  docs/                      # requirements, formats, discs, streaming, tak, lossy, …
  lib/                       # shared library (see lib/README.md)
    core/                    #   logging, config, XDG paths, plumbing
    cli/                     #   CLI/driver stack, workers, discovery
    media/                   #   probing, tags, cue/playlist, FLAC helpers
    pipeline/                #   conversion pipelines (PCM→FLAC, lossy, discs)
  conversion/<tool>/         # format converters (FLAC hub)
  util/<category>/<tool>/    # library lifecycle, grouped by category:
                             #   flac/ audio/ playlist/ audit/ library/
  tests/                     # test harness + unit/smoke/functional suites
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
