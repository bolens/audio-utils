#!/usr/bin/env bash
# Library inventory: sample rate, bit depth, RG, art, size totals.
#
# Usage:
#   flac-inventory.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-inventory.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Writes a summary report under XDG state (inventory-report.txt).
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 ok, 1 integrity failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
