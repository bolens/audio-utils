#!/usr/bin/env bash
# album-incomplete - flag incomplete albums (tracks/discs/duration outliers).
#
# Usage:
#   album-incomplete.sh DIR [DIR ...]
#   find-flac-dirs.sh | album-incomplete.sh
#
# Options:
#   --duration-ratio R   Outlier threshold vs median (default 0.35)
#   --no-duration        Skip duration outlier checks
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only: -d / -D / -y rejected. One result per directory.
# Complements album-audit (consistency) with completeness signals.
# Exit codes: 0 complete, 1 incomplete, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=15
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
