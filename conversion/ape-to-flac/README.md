# ape-to-flac

Monkey's Audio (.ape) → FLAC with PCM MD5 verify.

Part of **[audio-utils](../../)**.

## Workflow

This is the decode side of Monkey's Audio migration and does not require the
separate `mac` encoder used by `flac-to-ape`. FFmpeg must be able to decode the
particular APE revision in the source file.

```bash
./ape-to-flac.sh -n /path/to/album
./ape-to-flac.sh /path/to/album
```

The converter decodes the source, creates a temporary FLAC through the shared
verified pipeline, runs `flac -t`, and compares decoded PCM MD5 before an
atomic move into place. Existing FLAC siblings are skipped only when they pass
the same audio-identity check.

## Safety and compatibility

`-d` removes the `.ape` only after verified conversion; `-D` performs guarded
cleanup against an already matching FLAC. Preview deletion with `-n`. APE files
that FFmpeg cannot decode fail and remain untouched—there is no fallback that
weakens verification.

Requires the FFmpeg APE decoder, `ffprobe`, `flac`, and `metaflac`. See
[dependencies](../../docs/requirements.md) and
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert APE -> FLAC with PCM audio-MD5 verification.

Usage:
  ape-to-flac.sh DIR [DIR ...]
  find-*-dirs.sh | ape-to-flac.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
