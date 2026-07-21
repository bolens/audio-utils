#!/usr/bin/env bash
# Recompress FLACs without changing PCM (default -8).
#
# Usage:
#   flac-optimize.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-optimize.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -y  -h  --version
#   -c N / --compression N   FLAC level 0-8 (default 8)
#
# Skips when the new file is not smaller unless -y.
# Preserves Vorbis comments and embedded pictures.
# -d / -D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

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
