# dynamics-report

Read-only EBU R128 survey (ffmpeg `ebur128`): integrated loudness, loudness
range, true peak per file, plus a summary report listing low-LRA
(brickwall-suspect) files and true-peak overs.

Complements [`util/flac-replaygain`](../../flac/flac-replaygain/) /
[`util/audio-replaygain`](../../audio/audio-replaygain/) (which *write* gain tags) —
this tool only measures and reports.

Part of **[audio-utils](../../../)**.
