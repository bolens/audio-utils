#!/usr/bin/env bash
# genre-canonicalize — map freeform GENRE tags to a controlled list.
#
# Usage:
#   genre-canonicalize.sh DIR [DIR ...]
#   find-audio-dirs.sh | genre-canonicalize.sh --apply
#
# Options:
#   --apply              Write GENRE (default: report drift / unmapped)
#   --map-file=PATH      alias<TAB>Canonical lines (overrides built-in for hits)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Unmapped genres always fail. Missing GENRE is skipped (success).
# -d / -D rejected.
# Exit codes: 0 ok, 1 drift/unmapped, 2 usage/deps

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
