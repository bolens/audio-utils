#!/usr/bin/env bash
# silence-split - split long audio on silence into numbered FLAC tracks.
#
# Usage:
#   silence-split.sh DIR [DIR ...]
#   find-flac-dirs.sh | silence-split.sh
#
# Options:
#   --silence-sec SEC   Minimum silence length to split on (default 2.0)
#   --silence-db DB     Noise floor for silence (default -50)
#   --min-track SEC     Drop segments shorter than this (default 10)
#   --outdir DIR        Write tracks here (default: beside source)
#   -d                  Delete source after a successful multi-track split
#   -y                  Overwrite existing track files
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Requires at least 2 keep segments. Inverse of flac-cue-export / peer of cue-to-flac.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

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
