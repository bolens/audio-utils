# flac-authenticity

Read-only heuristics for FLACs that are **falsely tagged as high quality**:

| Verdict | Meaning |
|---------|---------|
| `likely-genuine` | No strong fake-quality signals |
| `suspect-lossy` | Spectral brickwall / weak HF (typical of MP3/AAC→FLAC) |
| `suspect-upsampled` | ≥88.2 kHz container with little energy above ~24 kHz |
| `suspect-padded` | Tagged ≥24-bit but low 16 bits are zero (16-bit data) |
| `inconclusive` | Too short or too quiet to judge |

Suspects fail the file (exit `1`); genuine / inconclusive succeed.

**Limits:** high-bitrate lossy (MP3 v0/320, high AAC) often has little brickwall and may pass. Use `-p` and inspect the PNG.

Part of **[audio-utils](../../../)**. See [docs/adding-a-util.md](../../../docs/adding-a-util.md).

## Requirements

- Linux, `bash` 4+, `flac`, `metaflac`, `ffmpeg`/`ffprobe`, `flock`, `od`, `awk`
- Optional: **`sox`** (nicer spectrograms with `-p`), **`mediainfo`** (claimed rate/depth/encoder in notes)

## Quick start

```bash
export AUDIO_UTILS_ROOTS="$HOME/Music"
./convert-all.sh -n
./convert-all.sh -q
./convert-all.sh -s -q              # stricter thresholds
./convert-all.sh -p -q              # PNG beside each suspect
./convert-all.sh -p --spectrogram-backend=both -q
```

With `-p`, suspects get a spectrogram beside the FLAC:

| Backend | Output |
|---------|--------|
| `sox` (default when sox installed) | `track.sox.png` |
| `ffmpeg` | `track.ff.png` |
| `both` | both files |

`mediainfo` (if installed) adds `mi_sr` / `mi_bps` / `mi_br` / `mi_enc` to the log notes, plus `mi-mismatch-*` when claims disagree with `ffprobe`/`metaflac`.

## Options

| Flag | Description |
|------|-------------|
| `-n` `-q` `-v` `-j N` `-f FILE` | Shared |
| `-L` / `-S` | Logs (XDG state defaults) |
| `-s` / `--strict` | Tighter spectral / padding thresholds |
| `-p` / `--spectrogram` | Write PNG next to **suspects** |
| `--spectrogram-all` | Write PNG for every checked file |
| `--spectrogram-backend=B` | `auto` \| `sox` \| `ffmpeg` \| `both` |
| `--version` | Version |

Read-only: `-d`, `-D`, and `-y` are rejected.

Exit codes: `0` all clean, `1` suspects found, `2` usage/deps.
