#!/usr/bin/env bash
# Detect tempo and save it as a tag (BPM; TBPM on MP3).
#
# Usage:
#   audio-bpm.sh DIR [DIR ...]
#   find-audio-dirs.sh | audio-bpm.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#
# Detection via bpm-tools (preferred) or aubio.
# FLAC uses metaflac; other formats remux with ffmpeg -c copy.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
