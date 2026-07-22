# Lossy encodes

## MP3 (`flac-to-mp3`)

Default quality remains **v0** (libmp3lame `-q:a 0`). Profiles: `v0`, `v2`, `320`, `192`.

```bash
AUDIO_UTILS_MP3_QUALITY=v0
# FLAC2MP3_QUALITY=v0
```

## Opus / AAC / Vorbis

Profiles live in shared `lib/pipeline/lossy.sh` (`lossy_resolve_quality`).

| Tool | Default `-Q` | Profiles |
|------|----------------|----------|
| flac-to-opus | `128` | `64` `96` `128` `160` `192` `256` (CBR kbps, libopus) |
| flac-to-aac | `192` | `128` `160` `192` `256` `320` (CBR kbps, aac) |
| flac-to-vorbis | `q6` | `q4`…`q8` (libvorbis `-q:a`) |

Env: `AUDIO_UTILS_OPUS_QUALITY`, `AUDIO_UTILS_AAC_QUALITY`, `AUDIO_UTILS_VORBIS_QUALITY`
(and tool-specific `FLAC2*_QUALITY` overrides).

## WMA / Speex

| Tool | Default `-Q` | Profiles |
|------|----------------|----------|
| flac-to-wma | `192` | `128` `160` `192` `256` (CBR kbps, wmav2) |
| flac-to-speex | `q6` | `q4`…`q8` (libspeex `-q:a`) |

Speex is speech-oriented; prefer Opus/MP3 for music.

Env: `AUDIO_UTILS_WMA_QUALITY`, `AUDIO_UTILS_SPEEX_QUALITY`.

## Musepack (`flac-to-mpc`)

Uses external **mpcenc** (`musepack-tools`), not an ffmpeg encoder.

| Profile | `--quality` | Approx |
|---------|-------------|--------|
| `telephone` | 2 | ~60 kbps |
| `radio` | 4 | ~130 kbps |
| `standard` (default) | 5 | ~180 kbps |
| `extreme` | 6 | ~210 kbps |
| `insane` | 7 | ~240 kbps |

Or numeric `0`–`10` (e.g. `5.5`). Env: `AUDIO_UTILS_MPC_QUALITY` / `FLAC2MPC_QUALITY`.

## Lossy → FLAC (`lossy-to-flac`)

Decodes MP3 / AAC / Opus / Vorbis / WMA / MPC / Speex (`.spx`) into FLAC for library
normalization. **Does not restore quality.** Skips ALAC-in-`.m4a` (use `alac-to-flac`).

## Resample / downmix

By default, if channels &gt; 2 or the sample rate is outside the codec allowlist, tools **resample and/or downmix** and log a note (`lossy_prepare_source`).

Fail closed (reject instead):

```bash
./conversion/flac-to-mp3/flac-to-mp3.sh -N …
# or
LOSSY_NO_RESAMPLE=1
```

Verification: duration within ~50ms; stream probe OK. Skip is probe-only (lossy cannot MD5-match PCM).

## See also

[docs index](README.md) · [formats.md](formats.md) · [requirements.md](requirements.md) · [adding-a-converter.md](adding-a-converter.md) · [`util/audit/lossy-audit/`](../util/audit/lossy-audit/) · [root README](../README.md)
