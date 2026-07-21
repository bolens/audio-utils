# tags-lookup

AcoustID fingerprint → MusicBrainz recording-id **report**. For each file:
fingerprint with `fpcalc`, query the AcoustID web service, and compare the
results against the embedded `MUSICBRAINZ_TRACKID`. Flags missing MBIDs (with
a candidate), mismatches, and files with no AcoustID match. Never writes tags
— fix with MusicBrainz Picard or [`util/flac-tags`](../../flac/flac-tags/).

**This is the only audio-utils tool that uses the network**, and only when a
key is supplied (`--client-key` / `ACOUSTID_CLIENT_KEY`). See
[docs/enrichment.md](../../../docs/enrichment.md). Requests are rate-limited
(`--delay`, default 0.4 s); prefer `-j 1`.

Part of **[audio-utils](../../../)**.
