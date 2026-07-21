#!/usr/bin/env bash
# Export spectrogram PNGs beside audio files (sox preferred, ffmpeg fallback).
#
# Usage:
#   spectrogram-export.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   -y              Overwrite existing .spectrogram.png
#
# -d / -D rejected. Output: <file>.spectrogram.png beside the source.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
