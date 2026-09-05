# flac-to-tta

FLAC → True Audio (.tta) with PCM MD5 verify.

Part of **[audio-utils](../../)**.

## Workflow and verification

This creates lossless TTA siblings for interoperability or codec testing while
retaining decoded sample identity.

```bash
./flac-to-tta.sh -n /path/to/album
./flac-to-tta.sh /path/to/album
```

The source FLAC is tested first. FFmpeg encodes a temporary TTA, which must
probe as TTA and decode to the same PCM MD5 before atomic installation.
Existing siblings are skipped only after the same codec and audio checks.

`-d` removes FLAC after verified conversion; cleanup-only `-D` requires an
already matching TTA. Since FLAC is the archive hub, use these only for an
intentional migration and preview with `-n`. Requires FFmpeg's `tta` encoder,
`ffprobe`, `flac`, and `flock`; see
[dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> TTA with PCM audio-MD5 verification.

Usage:
  flac-to-tta.sh DIR [DIR ...]
  find-*-dirs.sh | flac-to-tta.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
