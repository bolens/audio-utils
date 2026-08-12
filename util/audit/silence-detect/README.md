# silence-detect

Batch QC: fail on long leading/trailing silence (ffmpeg `silencedetect`) and
optional clipping. Scopes the portable+PCM cluster (`--preset portable-pcm`);
lossless archives (wv/ape/tak/tta) are out of scope unless you pass dirs by hand.
The analysis is a full error-strict decode; unreadable or truncated audio fails
instead of being interpreted as a clean, empty report.

Apply counterpart: [`silence-trim`](../../flac/silence-trim/) (report / `--apply`).
Peer of [`silence-split`](../../flac/silence-split/).

Part of **[audio-utils](../../../)**.
