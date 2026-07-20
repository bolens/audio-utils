#!/usr/bin/env bash
# Rewrite playlists dropping duplicate songs (keep first).
#
# Usage:
#   playlist-dedupe.sh DIR [DIR ...]
#
# Options:
#   --by path|title   Duplicate identity (default: path)
#   -y                Required to overwrite playlists that have dupes
#   -n  -j N  -q  -v  -h  --version  -f/-L/-S
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=12
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
