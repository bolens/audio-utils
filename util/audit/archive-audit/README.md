# archive-audit

Read-only discovery and verification for preservation packages carrying
`ARCHIVE_COMPLETE.json`, `SHA256SUMS`, and an audio-utils JSONL manifest.

The default full audit verifies checksums and the completion marker's declared
minisign, PAR2, preserved-stream, and sealing policy. Checksum paths are
confined to the package. It then
fully decodes FLAC files, compares STREAMINFO and manifest MD5/SHA/sample
values, rejects orphaned manifest records, and checks preserved `.source.mka`
codecs. `--quick` checks only package completion, checksums, and signatures.

`--snapshot-dir DIR` atomically records a filename-safe JSONL snapshot keyed by
the package's stable identifier. The identifier survives moving the package.
Use that directory later with `--baseline-dir DIR` to fail on added, removed, or
changed package files.

```bash
./archive-audit.sh /archive/root
./archive-audit.sh --snapshot-dir /audit/baseline /archive/root
./archive-audit.sh --baseline-dir /audit/baseline /archive/root
```

Part of **[audio-utils](../../../)**.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit preservation packages (checksums, provenance, FLAC, signatures, PAR2).

Usage:
  archive-audit.sh DIR [DIR ...]

Options:
  --quick               Checksums/signature only; skip semantic/decode audit
  --public-key KEY      Minisign public key
  --snapshot-dir DIR    Atomically write one current snapshot per package
  --baseline-dir DIR    Fail when current package differs from its snapshot
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only package audit: -d / -D / -y rejected.
Exit codes: 0 clean, 1 issues/drift, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
