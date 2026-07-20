# Lossy encodes

## MP3 (`flac-to-mp3`)

Default quality remains **v0** (libmp3lame `-q:a 0`). Profiles: `v0`, `v2`, `320`, `192`.

```bash
AUDIO_UTILS_MP3_QUALITY=v0
# FLAC2MP3_QUALITY=v0
```

## Opus / AAC / Vorbis

Profiles live in shared `lib/lossy.sh` (`lossy_resolve_quality`).

| Tool | Default `-Q` | Profiles |
|------|----------------|----------|
| flac-to-opus | `128` | `64` `96` `128` `160` `192` `256` (CBR kbps, libopus) |
| flac-to-aac | `192` | `128` `160` `192` `256` `320` (CBR kbps, aac) |
| flac-to-vorbis | `q6` | `q4`…`q8` (libvorbis `-q:a`) |

Env: `AUDIO_UTILS_OPUS_QUALITY`, `AUDIO_UTILS_AAC_QUALITY`, `AUDIO_UTILS_VORBIS_QUALITY`
(and tool-specific `FLAC2*_QUALITY` overrides).

## Resample / downmix

By default, if channels &gt; 2 or the sample rate is outside the codec allowlist, tools **resample and/or downmix** and log a note (`lossy_prepare_source`).

Fail closed (reject instead):

```bash
./conversion/flac-to-mp3/flac-to-mp3.sh -N …
# or
LOSSY_NO_RESAMPLE=1
```

Verification: duration within ~50ms; stream probe OK. Skip is probe-only (lossy cannot MD5-match PCM).
