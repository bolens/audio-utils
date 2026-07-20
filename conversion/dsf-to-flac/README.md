# dsf-to-flac

DSD Stream File (`.dsf`) / DSDIFF (`.dff`) → FLAC.

Decodes to PCM at **88200 Hz / 24-bit** by default (`AUDIO_UTILS_DSD_RATE`).
`.dff` may need **sox** when ffmpeg lacks a DSDIFF demuxer.

Part of **[audio-utils](../../)**. See also [docs/dsd.md](../../docs/dsd.md).
