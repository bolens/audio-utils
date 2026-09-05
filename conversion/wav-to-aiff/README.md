# wav-to-aiff

WAV → AIFF PCM remux with MD5 verify + tag copy.

Part of **[audio-utils](../../)**.

## Use and verification

This creates big-endian AIFF PCM siblings from WAV sources without an
intentional sample-rate or bit-depth conversion.

```bash
./wav-to-aiff.sh -n /path/to/session
./wav-to-aiff.sh /path/to/session
```

The shared PCM-remux pipeline probes both containers and compares decoded PCM
MD5 before the temporary output is moved into place. File hashes differ because
the container and byte order differ; decoded audio identity is the relevant
verification.

An existing AIFF is accepted only when its decoded audio matches the WAV.
`-d` and cleanup-only `-D` use that guard before removal. Preview with `-n`.
Not every WAV metadata chunk has an AIFF equivalent; preserve specialized BWF
or application-specific chunks separately. See
[format verification](../../docs/formats.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Remux WAV -> AIFF (PCM) with MD5 verification.

Usage:
  wav-to-aiff.sh DIR [DIR ...]
  find-*-dirs.sh | wav-to-aiff.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
