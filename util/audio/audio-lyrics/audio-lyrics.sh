#!/usr/bin/env bash
# Lyrics audit / sidecar sync: LYRICS tag vs .lrc / .txt sidecars.
#
# Usage:
#   audio-lyrics.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --import        Import sidecar .lrc/.txt into the LYRICS tag (FLAC only)
#   --export        Write <stem>.lrc sidecar from the LYRICS tag
#   -y              Overwrite existing tag (--import) or sidecar (--export)
#
# Default mode reports files with neither tag nor sidecar. -d / -D rejected.
# Exit codes: 0 ok/clean, 1 missing/failures, 2 usage/deps

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
