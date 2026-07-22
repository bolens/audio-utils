# silence-detect

Batch QC: fail on long leading/trailing silence (ffmpeg `silencedetect`) and
optional clipping. Scopes the portable+PCM cluster (`--preset portable-pcm`);
lossless archives (wv/ape/tak/tta) are out of scope unless you pass dirs by hand.

Part of **[audio-utils](../../../)**.
