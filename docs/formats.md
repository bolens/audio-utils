# Formats and verification

FLAC is the archive hub. Lossless tools verify with **PCM audio MD5** (and `flac -t` when writing FLAC). Lossy tools verify **duration ±50ms** and a successful stream probe.

```
WAV / AIFF / ALAC / WV / APE / TAK  ↔  FLAC  →  MP3 / Opus / AAC / Vorbis
CUE+image / streams / DVD / CDDA   →  FLAC
```

## Skip and `-D` cleanup

| Kind | Skip sibling when | `-D` deletes source when |
|------|-------------------|---------------------------|
| Lossless | probe OK **and** audio MD5 matches | same strong check |
| Lossy | probe OK only | probe OK only |

## Workdirs

Temps live beside media as `.${AUDIO_UTILS_WORKDIR_PREFIX}.*` and under XDG runtime for status dirs.
