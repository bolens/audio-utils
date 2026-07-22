# caf-to-flac

Apple Core Audio Format (`.caf`) → FLAC with PCM MD5 verify. Uses the same
PCM→FLAC pipeline as wav-to-flac / aiff-to-flac (`-c` clean replace, `-R` retag).

| Flag | Description |
|------|-------------|
| `-c` | Replace CAF with clean decode from FLAC |
| `-R` | Retag only: copy metadata onto existing valid FLACs |

Part of **[audio-utils](../../)**.
