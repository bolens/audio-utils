# audio-key

Detect musical key for FLAC and common portable formats (MP3 / Opus / M4A /
Ogg / WMA / MPC) and save it as a tag: `INITIALKEY` (vorbis comment /
freeform) or `TKEY` (MP3 ID3v2).

Detection via **keyfinder-cli** (libkeyfinder). Files that already carry a
key tag are skipped unless `-y` (overwrite). FLAC is tagged in place with
`metaflac`; other formats are remuxed with `ffmpeg -c copy` (audio MD5
verified unchanged).

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- `keyfinder-cli`
- `ffmpeg`/`ffprobe`, `flock`; `metaflac` for FLAC

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -q -C    # Camelot notation (8A instead of Am)
```

See also: [`util/audio-bpm/`](../audio-bpm/) for tempo tagging.
