#!/usr/bin/env bash
# Inventory VIDEO_TS / BDMV / CUE units under library roots.
#
# Usage:
#   disc-inventory.sh DIR [DIR ...]
#   find-disc-units.sh | disc-inventory.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
