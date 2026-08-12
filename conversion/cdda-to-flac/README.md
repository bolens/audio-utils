# cdda-to-flac

Rip audio CD tracks via **cdparanoia** → verified FLAC.
`-j` is accepted for CLI parity; the rip is serial.

```bash
./cdda-to-flac.sh                  # default /dev/sr0 → ./cdda-rip/
./cdda-to-flac.sh /dev/sr1 -o ~/Music/Album
./cdda-to-flac.sh -n               # dry-run: list tracks
```

Part of **[audio-utils](../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Rip audio CD -> FLAC via cdparanoia.

Usage:
  cdda-to-flac.sh [DEVICE] [-o OUTDIR]
  cdda-to-flac.sh -n                 # list tracks

Options:
  -o DIR      Output directory (default: ./cdda-rip)
  -d DEVICE   CD device (default: AUDIO_UTILS_CD_DEVICE, CDDA_DEVICE, or /dev/sr0)
  -L FILE  -S FILE  -n  -y  -q  -v  -h  --version
  -j N        Accepted for CLI parity; CDDA rip is serial (ignored)

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
