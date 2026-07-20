#!/usr/bin/env bash
# Convert FLAC → m4a (aac) with verification.
#
# Usage:
#   flac-to-aac.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-to-aac.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#   -Q PROFILE / --quality PROFILE
#   -N / --no-resample   Fail instead of resampling/downmixing
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
# shellcheck source=../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/cli.sh"
audio_utils_cli_run "$@"
