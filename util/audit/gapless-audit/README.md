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
