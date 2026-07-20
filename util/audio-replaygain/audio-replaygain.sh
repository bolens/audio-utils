#!/usr/bin/env bash
# ReplayGain for FLAC and common lossy formats (rsgain/loudgain).
#
# Usage:
#   audio-replaygain.sh DIR [DIR ...]
#   find-audio-dirs.sh | audio-replaygain.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -T / --track   Track gain only (default: album+track)
#
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
