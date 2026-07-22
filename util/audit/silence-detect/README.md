# silence-detect

Batch QC: fail on long leading/trailing silence (ffmpeg `silencedetect`) and
optional clipping. Scopes the portable+PCM cluster (`--preset portable-pcm`);
lossless archives (wv/ape/tak/tta) are out of scope unless you pass dirs by hand.

Apply counterpart: [`silence-trim`](../../flac/silence-trim/) (report / `--apply`).
Peer of [`silence-split`](../../flac/silence-split/).

Part of **[audio-utils](../../../)**.
