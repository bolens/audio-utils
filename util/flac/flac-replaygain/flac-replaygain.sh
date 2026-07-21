#!/usr/bin/env bash
# Apply ReplayGain 2.0 tags to FLACs (album by default; track-only optional).
#
# Usage:
#   flac-replaygain.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-replaygain.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -T / --track   Track gain only (default: album + track per directory)
#
# Requires: rsgain (preferred) or loudgain.
# -d / -D rejected. -y forces rewrite (skip-existing off).
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
