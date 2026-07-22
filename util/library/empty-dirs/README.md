# empty-dirs

Report empty directories left after prune/cleanup (artist/album shells with
nothing inside). Report-only by default (exit 1 when empties are found);
`-d` removes them with `rmdir`.

Pipe [`find-empty-dirs.sh`](find-empty-dirs.sh) for a deepest-first walk under
roots, then re-run after `-d` if parents become empty.

Companion to [`util/library/library-prune`](../library-prune/) and
[`util/library/junk-cleanup`](../junk-cleanup/).

Part of **[audio-utils](../../../)**.
