#!/usr/bin/env bash
# Detect musical key and save it as a tag (INITIALKEY; TKEY on MP3).
#
# Usage:
#   audio-key.sh DIR [DIR ...]
#   find-audio-dirs.sh | audio-key.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -C / --camelot   Camelot wheel notation (8A) instead of standard (Am)
#
# Detection via keyfinder-cli (libkeyfinder).
# FLAC uses metaflac; other formats remux with ffmpeg -c copy.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=15
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
