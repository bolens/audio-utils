# gapless-audit

Read-only check that portable lossy files carry gapless-playback metadata:
MP3 needs a Xing/Info header plus a LAME (or Lavc/Lavf) encoder tag with
delay/padding; M4A needs the `iTunSMPB` tag. ADTS `.aac` is always flagged —
the container has nowhere to store it (remux to `.m4a`).

Opus and Vorbis are gapless by design and not scanned.

Part of **[audio-utils](../../../)**.
