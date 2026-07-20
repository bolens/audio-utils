#!/usr/bin/env bash
# Detect falsely tagged FLAC quality (lossy→FLAC, upsampled “hi-res”, padded 16→24).
#
# Usage:
#   flac-authenticity.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-authenticity.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   -s / --strict              tighter thresholds (more catches, more FPs)
#   -p / --spectrogram         write PNG beside suspects (sox preferred, else ffmpeg)
#   --spectrogram-all          write PNG for every file checked
#   --spectrogram-backend=B    auto|sox|ffmpeg|both (default: auto)
#
# Heuristics (not ground truth):
#   - spectral brickwall / weak HF → suspect-lossy (transcoded MP3/AAC/…)
#   - ≥88.2 kHz with dead ultrasonics → suspect-upsampled
#   - 24-bit with zero low 16 bits → suspect-padded
# Optional: mediainfo fields in notes when installed; -p writes .sox.png / .ff.png
#
# High-bitrate lossy (e.g. MP3 v0/320) often passes — open the spectrogram PNG.
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 all clean, 1 suspects found, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=22
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
