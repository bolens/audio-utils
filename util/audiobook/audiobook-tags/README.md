# audiobook-tags

Normalize audiobook metadata: author (`ALBUMARTIST`), narrator (`NARRATOR`),
series (`SERIES` / `SERIES-PART`), genre `Audiobook`. Report-only by default;
`--apply` writes.

Default scope: audiobook-ish `GENRE`, existing narrator/series/ids, or `.m4b`.
Use `--all-genres` to process everything. Rejects `-d`/`-D`/`-y`.

See [audiobooks](../../../docs/audiobooks.md). Part of **[audio-utils](../../../)**.

```bash
./audiobook-tags.sh -n DIR
./audiobook-tags.sh --apply DIR
make help
```

## Normalization policy

Author is represented by `ALBUMARTIST` and can fill a missing `ARTIST`;
narrator and series use `NARRATOR`, `SERIES`, and `SERIES-PART`. Empty or
spoken-word-junk genre values become `Audiobook`, while ASIN/ISBN identifiers
are preserved when present.

Default scope avoids retagging unrelated music merely because it shares a
supported extension. `--all-genres` deliberately removes that filter and
should be previewed carefully.

Report mode describes drift without writing. `--apply` edits FLAC through
`metaflac` and remuxes other supported containers without audio re-encoding.
Custom container metadata may not round-trip through the core tag model. The
tool rejects generic overwrite/deletion flags; mutation is available only
through `--apply`. See [audiobook tags](../../../docs/audiobooks.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
audiobook-tags - normalize author/narrator/series tags for audiobooks.

Usage:
  audiobook-tags.sh DIR [DIR ...]
  find-audio-dirs.sh | audiobook-tags.sh

Options:
  --apply            Write normalized tags (default: report only)
  --all-genres       Do not skip non-audiobook genres
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

-d / -D / -y rejected (use --apply). Default scope: audiobook-ish GENRE,
existing narrator/series/ASIN/ISBN, or .m4b.
Exit codes: 0 ok, 1 needs work, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
