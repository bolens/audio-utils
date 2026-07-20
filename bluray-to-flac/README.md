# bluray-to-flac

Hybrid Blu-ray / BDMV → FLAC (and decrypted `.m2ts` / `.mkv`).

- Uses **libbluray** + **libaacs** (+ operator `KEYDB.cfg`) and/or **MakeMKV** when present.
- Otherwise accepts **already-decrypted** media.
- This project does **not** ship AACS keys or BD+ dumps.

See **[docs/discs.md](../docs/discs.md)** and **[docs/streaming.md](../docs/streaming.md)** (Widevine forever out of scope).

Part of **[audio-utils](../)**.
