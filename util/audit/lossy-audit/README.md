# lossy-audit

Health check for portable lossy files: full error-strict audio decode, core
tags, decodable embedded/folder cover, and bitrate floor (default 128 kbps).

Part of **[audio-utils](../../../)**.

## Policy checks

Every file must probe and complete a strict full audio decode. The audit also
requires core library tags, checks that embedded or folder artwork is
decodable, and enforces an average bitrate floor. Override the default 128 kbps
policy for speech or high-quality portable libraries as appropriate.

```bash
./lossy-audit.sh /path/to/portable-library
./lossy-audit.sh --min-kbps 96 /path/to/speech
```

Bitrate is only a policy signal: VBR codecs and highly efficient formats may
sound appropriate below a threshold, while a high bitrate cannot prove source
authenticity. Use [`lossy-authenticity`](../lossy-authenticity/) for spectral
heuristics and interpret those results separately.

The audit is read-only and rejects `-d`, `-D`, and `-y`. Exit status `1` means
one or more health/policy findings or decode failures. See
[lossy codec guidance](../../../docs/lossy.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit lossy/portable library files (tags, cover, bitrate floor).

Usage:
  lossy-audit.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
  --min-kbps=N   Bitrate floor (default 128)

Read-only: -d / -D / -y rejected.
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
