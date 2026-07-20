# Streaming / download archives

**DRM-free and already-unlocked local files only.**

Purchased downloads, podcasts, self-hosted rips you are allowed to archive, and other files that open in `ffprobe` without a CDM go through the existing hub tools — for example `wav-to-flac`, `streams-to-flac`, `flac-to-mp3`, and the other converters.

## Forever out of scope

| System | Status |
|--------|--------|
| Widevine (L1/L3, browser CDM) | **Out of scope** — no decrypt, dump, or stream-rip tooling |
| FairPlay | **Out of scope** |
| PlayReady | **Out of scope** |
| Browser/EME CDM extraction | **Out of scope** |

audio-utils will not add converters or helpers that circumvent streaming DRM. Use DRM-free sources, or archives you already unlocked by lawful means outside this project.

See also: [formats.md](formats.md), [discs.md](discs.md) (optical is separate; Blu-ray hybrid still does not ship keys).
