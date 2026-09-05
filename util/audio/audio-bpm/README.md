# audio-bpm

Detect tempo for FLAC and the portable cluster (`AU_AUDIO_EXTS_DEFAULT`:
MP3 / Opus / M4A / Ogg / WMA / MPC / Speex / AAC) and save it as a tag: `BPM`
(vorbis comment / freeform) or `TBPM`
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

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Detect tempo and save it as a tag (BPM; TBPM on MP3).

Usage:
  audio-bpm.sh DIR [DIR ...]
  find-audio-dirs.sh | audio-bpm.sh

Options:
  -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version

Detection via bpm-tools (preferred) or aubio.
FLAC uses metaflac; other formats remux with ffmpeg -c copy.
-d / -D rejected.
Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
