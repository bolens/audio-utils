#!/usr/bin/env bash
# audio-compare — bit-identical / PCM MD5 / peak-diff vs an against tree.
#
# Usage:
#   audio-compare.sh --against=DIR DIR [DIR ...]
#   find-audio-dirs.sh | audio-compare.sh --against=DIR
#
# Options:
#   --against=DIR     Mirror tree to compare against (required)
#   --mode=md5|streaminfo|peak   Default md5 (ffmpeg decode MD5)
#   --peak-eps=N      Max abs peak delta for --mode=peak (default 0.001)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Requires AUDIO_UTILS_ROOTS so relative paths can be mirrored under --against.
# -d / -D rejected.
# Exit codes: 0 ok, 1 mismatches, 2 usage/deps

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
