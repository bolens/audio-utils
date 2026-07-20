#!/usr/bin/env bash
# Remux AIFF → WAV (PCM) with MD5 verification.
#
# Usage:
#   aiff-to-wav.sh DIR [DIR ...]
#   find-*-dirs.sh | aiff-to-wav.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=11
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
