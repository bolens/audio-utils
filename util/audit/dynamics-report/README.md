# dynamics-report

Read-only EBU R128 survey (ffmpeg `ebur128`): integrated loudness, loudness
range, true peak per file, plus a summary report listing low-LRA
(brickwall-suspect) files and true-peak overs.

Scopes the portable+PCM cluster (`--preset portable-pcm`); lossless archives
(wv/ape/tak/tta) are out of scope unless you pass dirs by hand.

Complements [`util/flac-replaygain`](../../flac/flac-replaygain/) /
[`util/audio-replaygain`](../../audio/audio-replaygain/) (which *write* gain tags) —
this tool only measures and reports.

Part of **[audio-utils](../../../)**.
