# flac-to-ape

FLAC → Monkey's Audio (.ape) via the `mac` encoder, with PCM MD5 verify
(encode, decode back with ffmpeg, compare audio MD5s).

No distro ships a Monkey's Audio binary; build and install one with:

```bash
scripts/ape-codec.sh install     # → ~/.local/bin/mac (XDG-compliant)
```

The tool finds `mac` via `AUDIO_UTILS_MAC`, `PATH`, or `~/.local/bin/mac`.

Compression level: `-Q fast|normal|high|extrahigh|insane` (or `1000`–`5000`;
default `normal`, env `AUDIO_UTILS_APE_LEVEL`).

Note: `mac` writes no tags, so Vorbis comments from the FLAC are dropped;
conversions of tagged sources are marked `tags=dropped` in the success log.

Part of **[audio-utils](../../)**.
