#!/usr/bin/env bash
# Convert ALAC (.m4a) → FLAC. Non-ALAC m4a files are skipped.
#
# Usage:
#   alac-to-flac.sh DIR [DIR ...]
#   find-m4a-dirs.sh | alac-to-flac.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=11
# shellcheck source=../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/cli.sh"
audio_utils_cli_run "$@"
