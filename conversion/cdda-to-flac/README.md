# cdda-to-flac

Rip audio CD tracks via **cdparanoia** → verified FLAC.
`-j` is accepted for CLI parity; the rip is serial.

```bash
./cdda-to-flac.sh                  # default /dev/sr0 → ./cdda-rip/
./cdda-to-flac.sh /dev/sr1 -o ~/Music/Album
./cdda-to-flac.sh -n               # dry-run: list tracks
```

Part of **[audio-utils](../../)**.

## Device, output, and limits

The device defaults to `/dev/sr0` and can be selected with `-d DEVICE` or
`AUDIO_UTILS_CD_DEVICE`. Here `-d` names the device; it does not mean deletion.
Tracks are ripped serially with cdparanoia into the selected output directory.

```bash
./cdda-to-flac.sh -d /dev/sr0 -o /path/to/rip
```

Each track is encoded and tested as FLAC. This validates produced files but
does not perform AccurateRip consensus or MusicBrainz lookup; those workflows
remain external. Keep ripping logs and investigate reported read problems
before treating output as archival. Requires `cdparanoia`; see
[disc workflows](../../docs/discs.md).

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
