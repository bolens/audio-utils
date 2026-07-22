#!/usr/bin/env bash
# multi-disc-layout - put multi-disc albums into Disc N/ folders from tags.
#
# Usage:
#   multi-disc-layout.sh DIR [DIR ...]
#   find-flac-dirs.sh | multi-disc-layout.sh --apply
#
# Options:
#   --apply           Move files (default: report candidates as failures)
#   --prefix=NAME     Folder prefix (default: Disc -> "Disc 1")
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Multi-disc when any track has DISCNUMBER>1 or TOTALDISCS>1. Single-disc albums
# are left flat. Prefer setting TOTALDISCS on all tracks.
#
# -d / -D rejected.
# Exit codes: 0 ok, 1 candidates/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=17
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
