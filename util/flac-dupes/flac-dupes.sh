#!/usr/bin/env bash
# Find content-duplicate FLACs under library roots.
#
# Usage:
#   flac-dupes.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-dupes.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   -M / --md5            Use ffmpeg decode MD5 instead of STREAMINFO
#   --fingerprint         Chromaprint fpcalc (exact fingerprint match)
#
# First file per content key succeeds; later matches fail (exit 1).
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 no dupes, 1 dupes/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=15
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
