# audio-key

Detect musical key for FLAC and the portable cluster (`AU_AUDIO_EXTS_DEFAULT`:
MP3 / Opus / M4A / Ogg / WMA / MPC / Speex / AAC) and save it as a tag:
`INITIALKEY` (vorbis comment /
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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Detect musical key and save it as a tag (INITIALKEY; TKEY on MP3).

Usage:
  audio-key.sh DIR [DIR ...]
  find-audio-dirs.sh | audio-key.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
  -C / --camelot   Camelot wheel notation (8A) instead of standard (Am)

Detection via keyfinder-cli (libkeyfinder).
FLAC uses metaflac; other formats remux with ffmpeg -c copy.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
