#!/usr/bin/env bash
# lossy-authenticity - detect re-encoded / fake high-bitrate lossy files.
#
# Usage:
#   lossy-authenticity.sh DIR [DIR ...]
#   find-lossy-dirs.sh | lossy-authenticity.sh
#
# Options:
#   -s / --strict   Tighter spectral cliffs; flag ffmpeg encoder strings
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only: -d / -D / -y rejected.
# Heuristic (not proof). Complements lossy-audit and flac-authenticity.
# Exit codes: 0 ok, 1 suspects, 2 usage/deps

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
