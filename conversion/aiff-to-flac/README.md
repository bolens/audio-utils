# aiff-to-flac

Verified AIFF/AIF → FLAC (same remux / dual-encode / e2e MD5 bar as wav-to-flac).

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
make convert-quiet
```

Options: `-d` delete source, `-c` clean source from FLAC decode, `-D` cleanup, `-R` retag.
