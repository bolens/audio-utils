# library-prune

Inverse of [`util/library-sync`](../library-sync/): for each portable lossy
file, require a master (same relative path, `--exts`, default `.flac`) under
`--flac-root`. Orphans — portable files whose master was deleted or renamed —
are reported (exit 1) or deleted with `-d`.

Part of **[audio-utils](../../)**.
