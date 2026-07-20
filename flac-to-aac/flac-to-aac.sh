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
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_USAGE_FILE="$0"
AU_USAGE_START=2
AU_USAGE_END=16
export AU_USAGE_FILE AU_USAGE_START AU_USAGE_END
# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"
# shellcheck source=../lib/driver.sh
source "${SCRIPT_DIR}/../lib/driver.sh"
audio_utils_load_config
audio_utils_run "$@"
