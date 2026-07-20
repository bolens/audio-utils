# DSD → FLAC (`dsf-to-flac`)

Converts DSD Stream File (`.dsf`) and DSDIFF (`.dff`) to FLAC via PCM downsample.

## Defaults

| Setting | Value |
|---------|--------|
| PCM rate | **88200** Hz (`AUDIO_UTILS_DSD_RATE`) |
| Bit depth | 24-bit (`pcm_s24le`) |

Common alternatives: `176400` (DSD64÷4), `352800` (DSD64÷2).

```bash
AUDIO_UTILS_DSD_RATE=176400 ./conversion/dsf-to-flac/dsf-to-flac.sh …
```

## Demuxers

- **DSF**: ffmpeg `dsf` demuxer (usual distro builds).
- **DFF**: many ffmpeg builds lack DSDIFF; the tool falls back to **sox** when present.

```bash
# Arch / CachyOS
sudo pacman -S sox
```

## Notes

DSD→PCM is a format change, not a lossless remux. Verify with the tool’s usual PCM MD5 against the decoded PCM (not the original DSD bitstream).

## See also

[docs index](README.md) · [formats.md](formats.md) · [requirements.md](requirements.md) · [adding-a-converter.md](adding-a-converter.md) · [root README](../README.md)
