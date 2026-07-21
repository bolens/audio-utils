#!/usr/bin/env bash
# Audit gapless-playback metadata: MP3 Xing/Info + LAME tag, M4A iTunSMPB.
#
# Usage:
#   gapless-audit.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only: -d / -D / -y rejected. ADTS .aac is always flagged (the
# container cannot carry gapless metadata).
# Exit codes: 0 clean, 1 issues, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
