# audio-dupes

Content duplicates across FLAC and lossy formats. Default: chromaprint
(`fpcalc`). Optional `-M` uses decode MD5.

Part of **[audio-utils](../../../)**.

## Choosing an identity mode

Fingerprint mode is the default and compares a 120-second Chromaprint plus its
reported duration. It is useful across codecs and bitrates, where file hashes
and decoded samples naturally differ. If a short or silent file produces no
fingerprint, the tool falls back to decoded-audio MD5.

`-M` / `--md5` always uses decoded PCM MD5. That is stronger for lossless
copies with identical sample data but will not group lossy encodes of the same
recording.

```bash
./audio-dupes.sh /path/to/library
./audio-dupes.sh --md5 /path/to/lossless-library
```

## Reading results

The first path for a content key is reported as unique. Later paths with the
same key fail with `duplicate of PATH`, and the final summary reports the
number of duplicate groups. Exit status `1` therefore means duplicates or
files that could not be fingerprinted/decoded, not that files were changed.

This is strictly an audit: `-d`, `-D`, and `-y` are rejected. Review reported
paths manually or use a dedicated verified deduplication tool when hardlinking
FLAC archives. Fingerprint mode requires `fpcalc`; both modes require
`ffmpeg`/`ffprobe`. See [dependencies](../../../docs/requirements.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Find content duplicates across FLAC and lossy formats.

Usage:
  audio-dupes.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --fingerprint   Chromaprint (default)
  -M / --md5      Decode audio MD5 instead

Read-only: -d / -D / -y rejected.
Exit codes: 0 no dupes, 1 dupes/failures, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
