#!/usr/bin/env bash
# flac-resample - intentional downsample / bit-depth change for archive FLACs.
#
# Usage:
#   flac-resample.sh --rate=44100 [--bits=16] DIR [DIR ...]
#   find-flac-dirs.sh | flac-resample.sh --rate=48000 --apply
#
# Options:
#   --rate=Hz         Target sample rate (e.g. 44100, 48000)
#   --bits=16|24      Target bit depth
#   --apply           Rewrite in place (default: report candidates as failures)
#   --allow-upsample  Permit increasing rate/depth (default: down only)
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Pairs with flac-authenticity “fake hi-res” findings. Preserves tags + art.
# -d / -D rejected.
# Exit codes: 0 ok, 1 candidates (report) or apply failures, 2 usage/deps

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
