# TAK encode / decode

ffmpeg can **decode** TAK. Encode uses the official Windows **Takc** CLI (works under Wine).

## Setup

1. Download Tak from the upstream site (Takc.exe).
2. Set config:

```bash
# ~/.config/audio-utils/config
AUDIO_UTILS_TAKC=/path/to/Takc.exe
```

Or put `takc`/`Takc` on `PATH`. If the path ends in `.exe`, the wrapper runs `wine Takc.exe …`.

## Presets (`flac-to-tak -Q`)

Default **`p2`**. Allowlist: `p0`…`p5`, optional suffixes `e` / `m` (e.g. `p3e`, `p4m`).

```bash
./conversion/flac-to-tak/flac-to-tak.sh -Q p4m /path/to/album
# or
AUDIO_UTILS_TAK_PRESET=p2
```

## Unicode paths

Takc is unreliable with non-ASCII paths. Tools encode via **ASCII temp paths** under the album workdir, then move the result into place.

## Verify

After encode: decode TAK → PCM audio MD5 must match source FLAC.

## See also

[docs index](README.md) · [formats.md](formats.md) · [requirements.md](requirements.md) · [adding-a-converter.md](adding-a-converter.md) · [root README](../README.md)
