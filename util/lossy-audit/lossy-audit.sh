#!/usr/bin/env bash
# Audit lossy/portable library files (tags, cover, bitrate floor).
#
# Usage:
#   lossy-audit.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --min-kbps=N   Bitrate floor (default 128)
#
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 clean, 1 issues, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
