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

## Chapter extraction

The input must contain usable chapter metadata. Chapters become numbered files
under a directory named after the book stem, with sanitized titles. AAC/ALAC
can normally be stream-copied to `.m4a`; Opus falls back to `.opus` when MP4
remuxing is unsupported.

Chapter ranges and outputs are probed before completion, and book metadata is
copied where the destination permits it. Existing valid tracks are retained.
The source M4B is always kept and deletion flags are rejected, preserving its
chapters, cover, and MP4-specific metadata. The tool does not infer chapters
from silence or bypass DRM. See [audiobook workflows](../../docs/audiobooks.md).

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
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
