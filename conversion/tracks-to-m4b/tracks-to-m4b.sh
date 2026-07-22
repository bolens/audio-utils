#!/usr/bin/env bash
# tracks-to-m4b - chapter files in a directory → one .m4b.
#
# Usage:
#   tracks-to-m4b.sh DIR [DIR ...]
#   find-audio-dirs.sh | tracks-to-m4b.sh
#
# Options:
#   --codec=aac|opus|alac   Encode codec (default: aac / AUDIO_UTILS_M4B_CODEC)
#   -Q N / --quality N      Bitrate kbps for aac/opus (default: 96)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#
# -d / -D rejected (chapter sources kept). Output: <parent>/<dirname>.m4b
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
