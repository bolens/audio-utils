#!/usr/bin/env bash
# Strip FLAC padding / APPLICATION blocks; optional core-tag-only rewrite.
#
# Usage:
#   flac-strip.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-strip.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   -c / --core-tags     Keep only ARTIST/ALBUM/TITLE/TRACK*/DATE/GENRE/…
#   -k / --no-picture    Also remove embedded pictures
#
# Default: remove PADDING + APPLICATION, keep pictures and all tags, refresh seekpoints.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=15
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
