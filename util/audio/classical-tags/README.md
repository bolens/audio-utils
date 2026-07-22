# classical-tags

Normalize classical role tags: `COMPOSER`, `PERFORMER`, `CONDUCTOR`, `WORK`,
`MOVEMENT`, `MOVEMENTNUMBER`. Report-only by default; `--apply` writes.

When `WORK` / `MOVEMENT` are empty, splits titles like
`Symphony No. 5: I. Allegro` or `Concerto - II. Adagio`. Optionally fills
`PERFORMER` from `ARTIST` when `COMPOSER` is set and differs.

Default scope: classical-ish `GENRE`, or files that already have `COMPOSER` /
`WORK`. Use `--all-genres` to process everything; `--require-roles` fails when
`COMPOSER` is missing.

Part of **[audio-utils](../../../)**.

```bash
./classical-tags.sh -n DIR
./classical-tags.sh --apply DIR
make help
```
