# gapless-audit

Read-only check that portable lossy files carry gapless-playback metadata:
MP3 needs a Xing/Info header plus a LAME or Lavc encoder tag with nonzero,
parseable delay/padding; M4A needs a structurally valid `iTunSMPB` tag with
delay or padding. ADTS `.aac` is always flagged —
the container has nowhere to store it (remux to `.m4a`).

MP3 headers are located from the first MPEG frame and its side-information
layout. Encoder-like strings in ID3 metadata are not accepted as LAME tags.

Opus and Vorbis are gapless by design and not scanned.

Part of **[audio-utils](../../../)**.

## What the audit proves

The checks validate that recognized encoder-delay and padding structures are
present and parseable. They do not play adjacent tracks or prove that album
boundaries are perceptually seamless; incorrect source segmentation can still
carry structurally valid metadata.

```bash
./gapless-audit.sh /path/to/portable-library
```

MP3 parsing follows the first MPEG frame and expected side-information offset,
which prevents unrelated ID3 text from masquerading as a LAME tag. M4A requires
a valid `iTunSMPB` with nonzero delay or padding. Raw ADTS AAC is flagged by
design because it lacks a container metadata location.

This is read-only and rejects mutation flags. Re-encode or remux using a tool
that preserves encoder delay, then rerun; do not “fix” a finding by inserting
unverified text metadata alone.

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Audit gapless-playback metadata: MP3 Xing/Info + LAME tag, M4A iTunSMPB.

Usage:
  gapless-audit.sh DIR [DIR ...]

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version

Read-only: -d / -D / -y rejected. ADTS .aac is always flagged (the
container cannot carry gapless metadata).
Exit codes: 0 clean, 1 issues, 2 usage/deps
```
<!-- END GENERATED COMMAND REFERENCE -->
