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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
classical-tags - normalize classical role tags (COMPOSER/WORK/MOVEMENT/…).

Usage:
  classical-tags.sh DIR [DIR ...]
  find-audio-dirs.sh | classical-tags.sh

Options:
  --apply            Write normalized tags (default: report only)
  --require-roles    Fail when COMPOSER is missing on classical tracks
  --all-genres       Do not skip non-classical genres
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

-d / -D / -y rejected (use --apply). Default scope: classical-ish GENRE
or existing COMPOSER/WORK tags.
Exit codes: 0 ok, 1 needs work, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
