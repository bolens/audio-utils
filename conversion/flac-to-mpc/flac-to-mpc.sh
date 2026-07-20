#!/usr/bin/env bash
# Convert FLAC → Musepack (.mpc) via mpcenc with duration verification.
#
# Usage:
#   flac-to-mpc.sh DIR [DIR ...]
#   find-*-dirs.sh | flac-to-mpc.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#   -Q PROFILE / --quality PROFILE   telephone|radio|standard|extreme|insane|0–10
#   -N / --no-resample
#   Env: AUDIO_UTILS_MPC_QUALITY, FLAC2MPC_QUALITY
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
