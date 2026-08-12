# tak-to-flac

TAK → FLAC (ffmpeg or Takc decode) with PCM MD5 verify.

Part of **[audio-utils](../../)**.

## Decoder selection

TAK decoding uses FFmpeg when supported and can use the official Takc decoder
when configured. Takc may be a native executable or a Windows executable run
through Wine; set `AUDIO_UTILS_TAKC` when it is not discoverable normally.

```bash
./tak-to-flac.sh -n /path/to/album
AUDIO_UTILS_TAKC=/path/to/takc ./tak-to-flac.sh /path/to/album
```

## Verification and metadata

The TAK stream is decoded to temporary PCM, encoded through the shared FLAC
pipeline, tested, and compared by decoded PCM MD5 before atomic installation.
Source tags are copied where readable. An existing sibling is accepted only if
it is a valid FLAC with matching decoded audio.

`-d` and cleanup-only `-D` are verification-gated. A decoder error leaves the
TAK source and any prior valid output untouched. Preview destructive runs with
`-n`.

See the detailed [TAK setup notes](../../docs/tak.md),
[dependencies](../../docs/requirements.md), and
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert TAK -> FLAC with PCM audio-MD5 verification.

Usage:
  tak-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | tak-to-flac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
