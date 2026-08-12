# streams-to-flac

Extract each audio stream in a container → `basename.aN.flac`.

Part of **[audio-utils](../../)**.

## Inputs and output layout

Supported container extensions include MKV, MKA, MP4, MOV, TS, M2TS, and AOB,
but acceptance is based on probing: a file must contain at least one audio
stream. Every audio stream is extracted, not just the default stream. For
`concert.mkv`, outputs are `concert.a0.flac`, `concert.a1.flac`, and so on in
the same directory.

```bash
./streams-to-flac.sh -n /path/to/media
./streams-to-flac.sh /path/to/media
```

Dry run reports the probed stream count and exact planned filenames.

## Verification and metadata

Each stream is decoded independently through the shared verified FLAC path.
Outputs must pass FLAC integrity and decoded-audio checks before installation.
Stream index and available codec, language, title, and channel-layout metadata
are retained as FLAC tags so similarly named streams remain distinguishable.
Lossy source streams remain lossy in information content even though their new
container is FLAC.

## Deletion semantics

`-d` deletes the source container only after every audio stream succeeds. A
partial extraction keeps the container. `-D` is rejected because there is no
single sibling output that proves all streams were preserved. Preview `-d`
with `-n`, especially for video containers whose non-audio content would also
be discarded.

This tool extracts decrypted/readable media only; it does not bypass streaming
DRM. See [streaming scope](../../docs/streaming.md),
[format verification](../../docs/formats.md), and
[dependencies](../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Extract all audio streams from media containers to FLAC.

Usage:
  streams-to-flac.sh DIR [DIR ...]
  find-media-dirs.sh | streams-to-flac.sh

Options:
  -f FILE  -d  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  (-D cleanup is unsupported; use -d to delete the container after extract)

Exit codes: 0 ok, 1 failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
