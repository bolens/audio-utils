#!/usr/bin/env bash
# Convert FLAC → TAK via Takc with MD5 verification.
#
# Usage:
#   flac-to-tak.sh DIR [DIR ...]
#   find-*-dirs.sh | flac-to-tak.sh
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
#   -Q PRESET / --quality PRESET   TAK preset p0–p5[em] (default p2)
#   Env: AUDIO_UTILS_TAK_PRESET, AUDIO_UTILS_TAKC
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
