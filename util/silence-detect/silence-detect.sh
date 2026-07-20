#!/usr/bin/env bash
# Detect long leading/trailing silence and clipping.
#
# Usage:
#   silence-detect.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --silence-sec=N   Min silence duration (default 1.0)
#   --silence-db=N    Noise floor dB (default -50)
#   --no-clip         Do not fail on clipping
#
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 clean, 1 issues, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
