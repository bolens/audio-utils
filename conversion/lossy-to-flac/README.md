# lossy-to-flac

Decode lossy audio (MP3 / AAC / Opus / Vorbis / Speex / WMA / MPC) → FLAC for library
normalization. **Does not restore lost quality** — the FLAC wraps decoded PCM.

Skips ALAC-in-`.m4a` (use [`alac-to-flac`](../alac-to-flac/)).

Part of **[audio-utils](../../)**.

## What normalization means

The source codec is decoded once and the resulting PCM is stored losslessly in
FLAC. Future processing no longer incurs another lossy generation, but the
information discarded by the original codec remains absent. Outputs are often
larger than their sources without sounding better.

```bash
./lossy-to-flac.sh -n /path/to/mixed-lossy-library
./lossy-to-flac.sh /path/to/mixed-lossy-library
```

Acceptance is based on the probed codec, not just extension. Supported inputs
include MP3, AAC, Opus, Vorbis, Speex, WMA, and Musepack. ALAC in `.m4a` is
rejected so it can follow the genuinely lossless `alac-to-flac` path.

## Verification and provenance

The decoded source PCM and final FLAC are compared by audio MD5, and the FLAC
must pass integrity testing before atomic installation. That proves the FLAC
preserves this decode, not that the original recording was lossless. Tags and
artwork are copied where available.

`-d` and `-D` use strong equality against the decoded lossy source, but deleting
the compact original also discards its original bitstream and codec provenance.
Retain it unless normalization policy explicitly permits removal. See
[lossy behavior](../../docs/lossy.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Decode lossy audio -> FLAC for library normalization (does not restore quality).

Usage:
  lossy-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | lossy-to-flac.sh

Accepts: .mp3 .m4a .aac .opus .ogg .oga .wma .mpc .spx (codec-gated; skips ALAC .m4a)

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
