# lossy-to-flac

Decode lossy audio (MP3 / AAC / Opus / Vorbis / Speex / WMA / MPC) → FLAC for library
normalization. **Does not restore lost quality** — the FLAC wraps decoded PCM.

Skips ALAC-in-`.m4a` (use [`alac-to-flac`](../alac-to-flac/)).

Part of **[audio-utils](../../)**.
