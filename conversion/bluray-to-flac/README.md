# bluray-to-flac

Authored Blu-ray titles / decrypted media → per-stream FLAC.

- Uses **MakeMKV** to resolve authored playlists from BDMV trees and devices.
- Accepts standalone decrypted `.m2ts`, `.mkv`, `.mka`, `.mp4`, and `.ts` media.
- This project does **not** ship AACS keys or BD+ dumps.
- `-j` is accepted for CLI parity; extract is serial per title.
- Media-directory subdirectories are mirrored below `flac/`; output names retain
  the source extension (for example `title.mkv.a0.flac`) to prevent collisions.
- FLAC tags record source codec, profile, language, title, and channel layout
  when available. Lossy inputs are marked `LOSSY_SOURCE=1` and reported.

Raw `BDMV/STREAM/*.m2ts` clips are not treated as titles: Blu-ray playlists can
join, trim, reuse, or branch clips. Install MakeMKV for BDMV/device input, or
pass standalone decrypted media explicitly.

See **[docs/discs.md](../../docs/discs.md)** and **[docs/streaming.md](../../docs/streaming.md)** (Widevine forever out of scope).

Part of **[audio-utils](../../)**.
