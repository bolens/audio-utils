# genre-canonicalize

Map freeform `GENRE` tags onto a small controlled vocabulary (Rock, Metal,
Electronic, …). Report-only by default; `--apply` rewrites the tag.

Optional `--map-file` with `alias<TAB>Canonical` (or `alias=Canonical`) lines —
map-file hits win over the built-in table. Unmapped genres fail; missing GENRE
is skipped.

Companion to [`util/audio/audio-tags`](../audio-tags/).

Part of **[audio-utils](../../../)**.

## Mapping behavior

Only the first semicolon- or slash-separated genre is considered. Matching is
case-insensitive and whitespace-trimmed. A custom map is checked before the
built-in vocabulary, making local policy deterministic and reviewable.

```bash
./genre-canonicalize.sh /path/to/library
./genre-canonicalize.sh --map-file genres.tsv /path/to/library
```

Default mode reports `from` and proposed `to` values and exits with findings.
`--apply` updates FLAC through `metaflac`; other formats are stream-copied
through a temporary remux, so audio is not re-encoded. Missing genres are
skipped, while unknown nonempty genres fail for explicit policy decisions.

Use report mode with the final map before applying. `-y`, `-d`, and `-D` are
rejected; mutation requires `--apply`.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
genre-canonicalize - map freeform GENRE tags to a controlled list.

Usage:
  genre-canonicalize.sh DIR [DIR ...]
  find-audio-dirs.sh | genre-canonicalize.sh --apply

Options:
  --apply              Write GENRE (default: report drift / unmapped)
  --map-file=PATH      alias<TAB>Canonical lines (overrides built-in for hits)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Unmapped genres always fail. Missing GENRE is skipped (success).
-d / -D rejected.
Exit codes: 0 ok, 1 drift/unmapped, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
