#!/usr/bin/env bash
# Audit file / directory names for portability (FAT/exFAT/NTFS, length, UTF-8).
#
# Usage:
#   path-audit.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --max-path=N    Also fail when the full path exceeds N bytes (e.g. 260)
#
# Read-only: -d / -D / -y rejected. Fix names with util/flac-rename.
# Exit codes: 0 clean, 1 issues, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
