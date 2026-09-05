# lossy-authenticity

Read-only heuristic for lossy re-encodes and “fake high bitrate” files.
Measures mid vs high-frequency RMS and compares the spectral cliff against the
claimed bitrate (e.g. ~320 kbps with a hard wall near 16 kHz).

Not proof — spectrograms and encoder tags still help. Complements
[`lossy-audit`](../lossy-audit/) (tags/cover/bitrate floor) and
[`flac-authenticity`](../../flac/flac-authenticity/) (lossless).

`-s` / `--strict` tightens cliffs and flags common `ffmpeg`/`lavc` encoder
strings on MP3/AAC.

Part of **[audio-utils](../../../)**.

```bash
./lossy-authenticity.sh -n DIR
./lossy-authenticity.sh --strict DIR
make help
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
lossy-authenticity - detect re-encoded / fake high-bitrate lossy files.

Usage:
  lossy-authenticity.sh DIR [DIR ...]
  find-lossy-dirs.sh | lossy-authenticity.sh

Options:
  -s / --strict   Tighter spectral cliffs; flag ffmpeg encoder strings
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected.
Heuristic (not proof). Complements lossy-audit and flac-authenticity.
Exit codes: 0 ok, 1 suspects, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
