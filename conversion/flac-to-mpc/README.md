# flac-to-mpc

FLAC → Musepack (`.mpc`) via **mpcenc** (`musepack-tools`). Default quality: **standard**.

Verify: duration ±50ms + stream probe. Requires `mpcenc` on `PATH`.

Core Vorbis comments (title, artist, album, album artist, date, track,
disc, genre, comment, composer) are copied to APEv2 tags via `mpcenc --tag`.
Embedded artwork is not carried over.

Part of **[audio-utils](../../)**.
