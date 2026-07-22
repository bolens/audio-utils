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
