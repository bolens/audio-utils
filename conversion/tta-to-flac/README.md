# tta-to-flac

True Audio (.tta) → FLAC with PCM MD5 verify.

Part of **[audio-utils](../../)**.

## Workflow and verification

Use this to bring lossless TTA files into the FLAC archive workflow without a
lossy transcode.

```bash
./tta-to-flac.sh -n /path/to/album
./tta-to-flac.sh /path/to/album
```

Each source is codec-checked, decoded, encoded to a temporary FLAC, tested with
`flac -t`, and compared by decoded PCM MD5. Only then is the output installed
atomically. Tags and artwork are copied where supported. A pre-existing FLAC
is skipped only if its audio matches the TTA source.

## Safety and requirements

`-d` deletes a source only after verified conversion; `-D` performs cleanup
only where a valid matching FLAC already exists. Use `-n` before destructive
runs. Requires FFmpeg TTA decoding, `ffprobe`, `flac`, and `metaflac`; see
[dependencies](../../docs/requirements.md) and
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert TTA -> FLAC with PCM audio-MD5 verification.

Usage:
  tta-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | tta-to-flac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
