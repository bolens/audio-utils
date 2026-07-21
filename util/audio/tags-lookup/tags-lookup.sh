#!/usr/bin/env bash
# AcoustID / MusicBrainz lookup report (network; opt-in via client key).
#
# Usage:
#   ACOUSTID_CLIENT_KEY=xxx tags-lookup.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --client-key=KEY   AcoustID application key (or ACOUSTID_CLIENT_KEY env)
#   --delay=SEC        Sleep before each lookup (default: 0.4; API limit 3/s)
#
# Read-only report: -d / -D / -y rejected. Never writes tags.
# Exit codes: 0 all matched, 1 mismatches/missing/no-match, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
