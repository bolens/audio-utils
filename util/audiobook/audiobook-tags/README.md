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
