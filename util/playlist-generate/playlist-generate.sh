#!/usr/bin/env bash
# Generate one .m3u per audio-containing directory (beside tracks).
#
# Usage:
#   playlist-generate.sh DIR [DIR ...]
#
# Options:
#   -y  overwrite existing .m3u
#   -n  -j N  -q  -v  -h  --version  -f/-L/-S
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=11
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
