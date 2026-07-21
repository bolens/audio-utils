# Online metadata enrichment

Everything in audio-utils works offline — with one deliberate exception:
[`util/tags-lookup`](../util/tags-lookup/). This page defines that boundary.

## The boundary

| | Offline tools (everything else) | `tags-lookup` |
|---|---|---|
| Network | Never | AcoustID web service only |
| Enabled by | — | Client key (`ACOUSTID_CLIENT_KEY` / `--client-key`) |
| Writes | Per tool | **Never** (report-only) |

No other tool may open a network connection. Tools that *could* be enriched
online (lyrics, cover art) deliberately stop at auditing local data —
[`util/audio-lyrics`](../util/audio-lyrics/) checks tags and `.lrc` sidecars
but does not fetch lyrics.

## tags-lookup

For each FLAC / MP3 / Opus / M4A / Ogg file:

1. Fingerprint locally with `fpcalc` (chromaprint).
2. Query `api.acoustid.org/v2/lookup` (`meta=recordingids`) with `curl`.
3. Compare returned MusicBrainz recording ids against the embedded
   `MUSICBRAINZ_TRACKID` tag.

Reported failures: `missing MUSICBRAINZ_TRACKID` (a candidate id is included
in the failure detail), `embedded MBID not in acoustid results`, and
`no acoustid match`. Clean files log `match`.

Writing MBIDs back is out of scope — use
[MusicBrainz Picard](https://picard.musicbrainz.org/) for interactive
matching, then re-run `tags-lookup` to verify.

### Setup

Register a free application key at
<https://acoustid.org/new-application>, then:

```bash
export ACOUSTID_CLIENT_KEY=your-key
make -C util/tags-lookup convert ARGS="-j 1"
```

### Rate limiting

AcoustID allows ~3 requests/second. The tool sleeps `--delay` seconds
(default 0.4) before each request **per job** — run with `-j 1` to respect
the global limit. `jq` improves response parsing when installed; without it a
coarse grep-based fallback is used.

## See also

[docs index](README.md) · [requirements.md](requirements.md) · [root README](../README.md)
