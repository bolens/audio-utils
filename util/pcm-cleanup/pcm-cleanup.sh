#!/usr/bin/env bash
# Find leftover WAV/AIFF/CAF beside verified FLAC siblings.
#
# Usage:
#   pcm-cleanup.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   -d              Delete PCM when FLAC sibling verifies (MD5 match)
#
# Default is report-only (exit 1 when leftovers found). -D rejected.
# Exit codes: 0 clean, 1 leftovers/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
