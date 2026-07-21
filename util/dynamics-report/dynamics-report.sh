#!/usr/bin/env bash
# Loudness / dynamics report: integrated LUFS, LRA, true peak (EBU R128).
#
# Usage:
#   dynamics-report.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --min-lra=N     Flag files with LRA below N LU in the report (default: 3)
#
# Read-only: -d / -D / -y rejected. Summary report written to the state dir.
# Exit codes: 0 ok, 1 unreadable files, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
