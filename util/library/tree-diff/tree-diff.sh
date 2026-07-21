#!/usr/bin/env bash
# Diff scanned library files against another tree (--against).
#
# Usage:
#   tree-diff.sh --against=BACKUP_ROOT DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --against=DIR   Comparison tree (required)
#   --hash          Also compare sha256
#
# Relative paths resolved via AUDIO_UTILS_ROOTS.
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 match, 1 diffs, 2 usage/deps

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
