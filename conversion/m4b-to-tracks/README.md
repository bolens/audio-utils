# m4b-to-tracks

One `.m4b` → per-chapter files in `<stem>/` beside the book
(`NN - Title.m4a`, stream-copy when possible). Opus falls back to `.opus` if
`.m4a` remux fails. Fails when the container has no chapters. Source `.m4b`
is kept (`-d`/`-D` rejected).

See [audiobooks](../../docs/audiobooks.md). Part of **[audio-utils](../../)**.

```bash
./m4b-to-tracks.sh -n DIR
make help
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
m4b-to-tracks - one .m4b → per-chapter files.

Usage:
  m4b-to-tracks.sh DIR [DIR ...]
  find-m4b-dirs.sh | m4b-to-tracks.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version

-d / -D rejected (source .m4b kept). Writes <stem>/NN - Title.m4a beside the book.
Fails when the .m4b has no chapters.
Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
