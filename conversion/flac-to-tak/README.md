# flac-to-tak

FLAC → TAK via Takc; verify by decode MD5. Default preset p2.

Limitation: `Takc` writes no tags, so Vorbis comments and artwork are not
carried into the `.tak` output. When the source has tags, the success log
notes column records `tags=dropped`. Re-tag with an APEv2 tagger if needed.

Part of **[audio-utils](../../)**.
