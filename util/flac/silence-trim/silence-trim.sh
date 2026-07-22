#!/usr/bin/env bash
# silence-trim - trim leading/trailing silence from FLAC/PCM (report / --apply).
#
# Usage:
#   silence-trim.sh DIR [DIR ...]
#   find-flac-dirs.sh | silence-trim.sh
#
# Options:
#   --silence-sec SEC   Min silence length to treat as edge (default 1.0)
#   --silence-db DB     Noise floor (default -50)
#   --pad-sec SEC       Keep this much silence at the cut (default 0.05)
#   --min-keep SEC      Abort if keep window would be shorter (default 1.0)
#   --lead-only         Trim leading silence only
#   --trail-only        Trim trailing silence only
#   --apply             Rewrite files in place (default: report candidates)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Report-only by default (exit 1 when candidates exist). -d/-D/-y rejected.
# Peer of silence-detect (QC) and silence-split (multi-track).
# Exit codes: 0 ok, 1 candidates/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=20
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
