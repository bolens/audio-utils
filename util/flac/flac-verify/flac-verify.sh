#!/usr/bin/env bash
# Verify FLAC integrity under library roots (flac -t; optional decode MD5).
#
# Usage:
#   flac-verify.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-verify.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   -M / --md5   Also decode via ffmpeg and record audio MD5
#                (and compare to STREAMINFO MD5 when non-zero)
#
# Read-only: -d / -D / -y are rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

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
