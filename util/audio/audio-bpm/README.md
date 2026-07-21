# audio-bpm

Detect tempo for FLAC and common portable formats (MP3 / Opus / M4A / Ogg /
WMA / MPC) and save it as a tag: `BPM` (vorbis comment / freeform) or `TBPM`
(MP3 ID3v2).

Detection via **bpm-tools** (`bpm`, preferred) or **aubio**. Files that
already carry a BPM tag are skipped unless `-y` (overwrite). FLAC is tagged
in place with `metaflac`; other formats are remuxed with `ffmpeg -c copy`
(audio MD5 verified unchanged).

Note: bpm-tools folds tempo into its default 84–146 BPM window, so
half/double-time values are possible.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- `bpm` (bpm-tools, preferred) or `aubio`
- `ffmpeg`/`ffprobe`, `flock`; `metaflac` for FLAC

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
```

See also: [`util/audio-key/`](../audio-key/) for musical key tagging.
