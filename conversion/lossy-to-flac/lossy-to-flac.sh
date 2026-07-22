#!/usr/bin/env bash
# Decode lossy audio → FLAC for library normalization (does not restore quality).
#
# Usage:
#   lossy-to-flac.sh DIR [DIR ...]
#   find-*-dirs.sh | lossy-to-flac.sh
#
# Accepts: .mp3 .m4a .aac .opus .ogg .oga .wma .mpc .spx (codec-gated; skips ALAC .m4a)
#
# Options:
#   -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
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
