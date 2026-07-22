# chapters

List / extract / embed chapter markers on `.m4b` / `.m4a` (ffmpeg ffmetadata).
Default: list chapters. `--extract=FILE` writes ffmetadata; `--embed=FILE`
with `--apply` (or `-y`) rewrites the container.

Rejects `-d`/`-D`. Peer of [`tracks-to-m4b`](../../../conversion/tracks-to-m4b/)
and [`m4b-to-tracks`](../../../conversion/m4b-to-tracks/). See [audiobooks](../../../docs/audiobooks.md).

Part of **[audio-utils](../../../)**.

```bash
./chapters.sh -n DIR
./chapters.sh --extract=chapters.txt DIR
./chapters.sh --embed=chapters.txt --apply DIR
make help
```
