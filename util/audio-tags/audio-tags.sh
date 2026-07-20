#!/usr/bin/env bash
# Normalize tags across FLAC and common lossy formats.
#
# Usage:
#   audio-tags.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -A / --fill-albumartist   Set album artist from artist when missing
#
# FLAC uses metaflac; other formats remux with ffmpeg -c copy.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
