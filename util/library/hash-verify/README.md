# hash-verify

Verify or write sidecar `.sha256` / `.md5` checksums beside audio files.

Part of **[audio-utils](../../../)**.

## Verify and write modes

Verification is the default. For each audio file, the tool expects a sidecar
named `<file>.sha256` (or `<file>.md5`) and compares its first whitespace-
delimited field with a newly computed checksum.

```bash
./hash-verify.sh /path/to/archive
./hash-verify.sh --md5 /path/to/legacy-set
```

`-w` / `--write` creates sidecars containing the checksum and basename. An
existing sidecar is retained unless `-y` is supplied, so writing does not
silently replace prior evidence.

```bash
./hash-verify.sh -n --write /path/to/archive
./hash-verify.sh --write --sha256 /path/to/archive
```

## Interpretation and safety

Missing sidecars, mismatches, and hash-command failures produce exit status
`1`. Checksums verify file bytes, including tags and artwork; they do not prove
that audio decodes correctly. Pair this with codec-aware audits such as
[`flac-verify`](../../flac/flac-verify/) for archival validation.

The tool never deletes media and rejects `-d`/`-D`. SHA-256 is the default and
is preferred for new sidecars; MD5 exists for compatibility with older sets.
Sidecars are created mode `0600` when supported.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Verify or write sidecar checksums (.sha256 / .md5) for audio files.

Usage:
  hash-verify.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -w / --write   Write sidecars (default: verify existing)
  --sha256       Use SHA-256 (default)
  --md5          Use MD5

-d / -D rejected.
Exit codes: 0 ok, 1 mismatches/missing, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
