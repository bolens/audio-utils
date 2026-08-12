# audiobook-audit

Read-only QC for single-file `.m4b` books and multi-file chapter directories:
missing cover / author / narrator / title, chapterless `.m4b`, unexpected
codecs (AAC/Opus/ALAC OK), series consistency, track gaps / mixed rates.
Audio is fully decoded during the audit; multi-file books also reject duplicate
and non-contiguous track numbers and invalid artwork.

See [audiobooks](../../../docs/audiobooks.md). Part of **[audio-utils](../../../)**.

```bash
./audiobook-audit.sh -n DIR
make help
```

## Unit model and findings

An M4B is audited as one file. Multi-file books are coordinated once per
directory and checked as a chapter set. Full strict decoding catches truncated
media that tag-only inspection would miss.

Single-file checks distinguish missing or trivial chapters, unsupported codecs,
invalid cover art, and incomplete author/narrator/series metadata. Multi-file
checks add contiguous unique track numbering, consistent declared totals,
sample rates, titles, and series fields.

A finding reflects library policy and may require judgment—for example, some
books legitimately lack a narrator tag or intentionally mix sample rates. The
tool is read-only and rejects `-d`, `-D`, and `-y`. Normalize with
`audiobook-tags`, repair chapters separately, and rerun. See
[audiobook workflows](../../../docs/audiobooks.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
audiobook-audit - QC for .m4b books and multi-file chapter dirs.

Usage:
  audiobook-audit.sh DIR [DIR ...]
  find-audio-dirs.sh | audiobook-audit.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only (-d/-D/-y rejected). Checks cover, author, narrator, chapters,
series consistency, and unexpected .m4b codecs.
Exit codes: 0 ok, 1 issues found, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
