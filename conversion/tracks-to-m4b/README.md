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
```
<!-- END GENERATED COMMAND REFERENCE -->
