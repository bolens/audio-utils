#!/usr/bin/env bash
# Audit playlist files (missing paths, empty, duplicates, UTF-8).
#
# Usage:
#   playlist-audit.sh DIR [DIR ...]
#
# Options:
#   --by path|title   Duplicate identity (default: path)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 clean, 1 issues, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
