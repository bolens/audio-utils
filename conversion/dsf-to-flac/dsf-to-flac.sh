#!/usr/bin/env bash
# Convert DSD (DSF/DFF) → FLAC via PCM downsample.
#
# Default PCM rate: 88200 Hz / 24-bit (override: AUDIO_UTILS_DSD_RATE).
# DFF: ffmpeg first; sox fallback if demuxer missing.
#
# Usage:
#   dsf-to-flac.sh DIR [DIR ...]
#   find-*-dirs.sh | dsf-to-flac.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
