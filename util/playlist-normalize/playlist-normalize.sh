#!/usr/bin/env bash
# Rewrite playlists: format and/or relative↔absolute paths; optional dedupe.
#
# Usage:
#   playlist-normalize.sh DIR [DIR ...]
#
# Options:
#   --format m3u|pls|xspf   Output format (default: same as input)
#   --relative              Paths relative to playlist dir (default)
#   --absolute              Absolute paths
#   --dedupe                Drop duplicate entries while rewriting
#   --by path|title         Dedupe identity when --dedupe (default: path)
#   -y  -n  -j N  -q  -v  -h  --version  -f/-L/-S
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=15
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
