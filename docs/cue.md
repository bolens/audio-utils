# CUE → FLAC (`cue-to-flac`)

Splits a CUE + single image file into `NN - Title.flac` next to the CUE.

## Layout

```
Album/
  Album.cue
  Album.flac   # or .wav / .ape / …
```

- Tracks use `INDEX 01` only (75 frames/sec).
- Album TITLE/PERFORMER apply unless overridden per TRACK.
- Image resolved beside the CUE (exact name, then common extensions).
- Tracks within one CUE run **serially**; multiple CUEs can run in parallel via `-j`.

## Limits

- No pregaps/`INDEX 00` gap handling beyond start at INDEX 01.
- Non-UTF-8 CUE sheets may need conversion first.
- Filename sanitization strips path separators and control chars.
- `|` in TITLE/PERFORMER is stripped when emitting internal track records (pipe-delimited).

See also: [formats.md](formats.md) · [discs.md](discs.md) · [requirements.md](requirements.md) · [`util/audit/cue-audit/`](../util/audit/cue-audit/) · [`util/flac/flac-cue-export/`](../util/flac/flac-cue-export/) · [docs index](README.md) · [root README](../README.md)
