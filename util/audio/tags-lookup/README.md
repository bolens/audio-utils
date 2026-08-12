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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
AcoustID / MusicBrainz lookup report (network; opt-in via client key).

Usage:
  ACOUSTID_CLIENT_KEY=xxx tags-lookup.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --client-key=KEY   AcoustID application key (or ACOUSTID_CLIENT_KEY env)
  --delay=SEC        Sleep before each lookup (default: 0.4; API limit 3/s)

Read-only report: -d / -D / -y rejected. Never writes tags.
Exit codes: 0 all matched, 1 mismatches/missing/no-match, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
