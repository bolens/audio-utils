# flac-to-alac

Verified FLAC → ALAC (`.m4a`). Skip/cleanup require `codec=alac` and matching audio MD5.

## When to use it

Use ALAC for a lossless portable or Apple-library copy while retaining FLAC as
the archive source. Outputs are written as sibling `.m4a` files; directory
layout is unchanged.

```bash
./flac-to-alac.sh -n /path/to/album
./flac-to-alac.sh /path/to/album
```

## Verification and cleanup

The FLAC is validated before conversion. The resulting file must probe as
ALAC, decode successfully, and match the source's decoded PCM MD5. Tags and
artwork are copied through the shared lossless pipeline, and the completed
file is installed atomically.

An existing `.m4a` is never trusted by name alone: skip and `-D` cleanup both
require an ALAC codec and matching audio. `-d` deletes the FLAC only after a
new verified output succeeds. Use `-n` before either deletion workflow.

## Requirements and interoperability

Requires the `alac` encoder in `ffmpeg`, plus `ffprobe`, `flac`, and `flock`.
ALAC is lossless, but the MP4/M4A tag model differs from FLAC; inspect unusual
custom tags when metadata fidelity matters. See
[format verification](../../docs/formats.md) and
[dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> ALAC (.m4a) with PCM audio-MD5 verification.

Usage:
  flac-to-alac.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-alac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
