#!/usr/bin/env bash
# Embed folder covers into FLACs, or extract embedded pictures to the album dir.
#
# Usage:
#   flac-artwork.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-artwork.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -x / --extract   Export embedded picture to cover.jpg (default: embed)
#
# Looks for cover.jpg|png, folder.jpg|png, front.jpg|png, AlbumArt*.jpg (case-insensitive).
# -d / -D rejected. -y overwrites existing embedded art / cover file.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
# shellcheck source=../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/cli.sh"
audio_utils_cli_run "$@"
