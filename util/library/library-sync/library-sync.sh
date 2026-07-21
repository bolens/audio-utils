#!/usr/bin/env bash
# Check each FLAC has a portable sibling under another library root.
#
# Usage:
#   library-sync.sh --portable-root=DIR DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --portable-root=DIR   Required portable/lossy library root
#   --exts=mp3,opus,m4a   Sibling extensions to accept (default mp3 opus m4a ogg)
#
# Requires AUDIO_UTILS_ROOTS (or scanned dirs under it) to resolve relative paths.
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 ok, 1 missing siblings, 2 usage/deps

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
