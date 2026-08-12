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
