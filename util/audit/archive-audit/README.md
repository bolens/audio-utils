# archive-audit

Read-only discovery and verification for preservation packages carrying
`ARCHIVE_COMPLETE.json`, `SHA256SUMS`, and an audio-utils JSONL manifest.

The default full audit verifies checksums, optional minisign and PAR2 data,
fully decodes FLAC files, compares STREAMINFO and manifest MD5/SHA/sample
values, rejects orphaned manifest records, and checks preserved `.source.mka`
codecs. `--quick` checks only package completion, checksums, and signatures.

`--snapshot-dir DIR` atomically records a keyed file snapshot for every package.
Use that directory later with `--baseline-dir DIR` to fail on added, removed, or
changed package files.

```bash
./archive-audit.sh /archive/root
./archive-audit.sh --snapshot-dir /audit/baseline /archive/root
./archive-audit.sh --baseline-dir /audit/baseline /archive/root
```

Part of **[audio-utils](../../../)**.
