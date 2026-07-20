#!/usr/bin/env bash
# Recompress FLACs without changing PCM (default -8).
#
# Usage:
#   flac-optimize.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-optimize.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -c N / --compression N   FLAC level 0-8 (default 8)
#
# Skips when the new file is not smaller unless -y.
# Preserves Vorbis comments and embedded pictures.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=15
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
