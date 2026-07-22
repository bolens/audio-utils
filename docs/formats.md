# Formats and verification

FLAC is the archive hub. Lossless tools verify with **PCM audio MD5** (and `flac -t` when writing FLAC). Lossy tools verify **duration ±50ms** and a successful stream probe.

```
WAV / AIFF / CAF / ALAC / WV / APE / TAK / TTA  ↔  FLAC  →  MP3 / Opus / AAC / Vorbis / WMA / Speex / MPC
SHN / DSD / lossy (normalize) / CUE+image / streams / DVD / CDDA   →  FLAC
```

## Skip and `-D` cleanup

| Kind | Skip sibling when | `-D` deletes source when |
|------|-------------------|---------------------------|
| Lossless | probe OK **and** audio MD5 matches | same strong check |
| Lossy | probe OK only | probe OK only |

## Workdirs

Temps live beside media as `.${AUDIO_UTILS_WORKDIR_PREFIX}.*` and under XDG runtime for status dirs.

## Extension presets

Shared clusters live in [`lib/media/audio_exts.sh`](../lib/media/audio_exts.sh).
`find-audio-dirs.sh --preset NAME` and several utils consume them:

| Preset | Contents |
|--------|----------|
| `portable` | flac + common lossy (incl. speex) |
| `portable-pcm` | portable + wav/aiff/caf |
| `pcm` | wav/aiff/caf only |
| `lossy` | lossy only |
| `portable-pcm-archive` | portable-pcm + wv/ape/tak/tta |
| `library` | archive cluster + cue/m3u/cover sidecars |
| `library-junk` | library + junk (`.db` / `.ini` / …) |
| `viz` | formats suited to spectrogram / waveform tools |

## See also

[docs index](README.md) · [requirements.md](requirements.md) · [lossy.md](lossy.md) · [cue.md](cue.md) · [discs.md](discs.md) · [dsd.md](dsd.md) · [tak.md](tak.md) · [streaming.md](streaming.md) · [playlists.md](playlists.md) · [adding-a-converter.md](adding-a-converter.md)
