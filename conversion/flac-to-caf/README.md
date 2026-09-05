# flac-to-caf

FLAC → Apple CAF (PCM) with PCM MD5 verify.

Part of **[audio-utils](../../)**.

## Scope and workflow

Use this when software requires Core Audio Format while FLAC remains the
archive source. The sibling `.caf` contains uncompressed PCM, so expect it to
be substantially larger than the source.

```bash
./flac-to-caf.sh -n /path/to/album
./flac-to-caf.sh /path/to/album
```

The FLAC is integrity-tested, decoded into CAF, and the result is decoded again
for PCM-MD5 comparison before atomic installation. Existing CAF siblings are
skipped only after matching source audio.

`-d` deletes FLAC only after verified conversion; `-D` verifies an existing
CAF before cleanup. These are usually inappropriate when FLAC is the archive
master, so preview with `-n`. CAF does not share FLAC's complete metadata and
picture model; treat it as an audio-preserving compatibility copy. See
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> Apple CAF (PCM) with PCM audio-MD5 verification.

Usage:
  flac-to-caf.sh DIR [DIR ...]
  find-*-dirs.sh | flac-to-caf.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
