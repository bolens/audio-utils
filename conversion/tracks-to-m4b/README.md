# tracks-to-m4b

Ordered chapter files in a directory → one `.m4b` with embedded chapters,
cover (best-effort), and book tags. Codecs: `--codec=aac|opus|alac`
(default `aac` / `AUDIO_UTILS_M4B_CODEC`). Quality: `-Q` / `AUDIO_UTILS_M4B_QUALITY`
(default **96**; ignored for ALAC).

Output: `<parent>/<dirname>.m4b`. Chapter sources are kept (`-d`/`-D` rejected).

See [audiobooks](../../docs/audiobooks.md). Part of **[audio-utils](../../)**.

```bash
./tracks-to-m4b.sh -n DIR
./tracks-to-m4b.sh --codec=opus -Q 64 DIR
make help
```

## Ordering, chapters, and metadata

Files are sorted by bytewise filename order, so numeric prefixes should be
zero-padded for predictable chapter sequence. Chapter titles prefer `TITLE`
and otherwise derive from filenames; chapter boundaries use measured file
durations.

The first track supplies book-level title/album, author, narrator, series, and
genre defaults. Folder or embedded cover art is added best-effort. AAC provides
widest playback support, Opus is efficient but less universal in MP4, and ALAC
keeps decoded audio lossless.

The finished M4B must probe and its duration must match summed tracks within
about 50 ms before atomic installation. Existing readable output is retained
unless replacement is requested. Source chapters are always kept and deletion
flags are rejected. See [audiobook workflows](../../docs/audiobooks.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
tracks-to-m4b - chapter files in a directory → one .m4b.

Usage:
  tracks-to-m4b.sh DIR [DIR ...]
  find-audio-dirs.sh | tracks-to-m4b.sh

Options:
  --codec=aac|opus|alac   Encode codec (default: aac / AUDIO_UTILS_M4B_CODEC)
  -Q N / --quality N      Bitrate kbps for aac/opus (default: 96)
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version

-d / -D rejected (chapter sources kept). Output: <parent>/<dirname>.m4b
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
