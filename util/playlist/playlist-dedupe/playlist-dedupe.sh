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
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
