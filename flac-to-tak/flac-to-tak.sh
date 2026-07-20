#!/usr/bin/env bash
# Convert FLAC → TAK via Takc with MD5 verification.
#
# Usage:
#   flac-to-tak.sh DIR [DIR ...]
#   find-*-dirs.sh | flac-to-tak.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#   -Q PRESET / --quality PRESET   TAK preset p0–p5[em] (default p2)
#   Env: AUDIO_UTILS_TAK_PRESET, AUDIO_UTILS_TAKC
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_USAGE_FILE="$0"
AU_USAGE_START=2
AU_USAGE_END=13
export AU_USAGE_FILE AU_USAGE_START AU_USAGE_END
# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"
# shellcheck source=../lib/driver.sh
source "${SCRIPT_DIR}/../lib/driver.sh"
audio_utils_load_config
audio_utils_run "$@"
