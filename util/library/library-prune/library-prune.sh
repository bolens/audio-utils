#!/usr/bin/env bash
# Find portable files whose FLAC master no longer exists (inverse of
# library-sync). Report-only by default; -d deletes orphans.
#
# Usage:
#   library-prune.sh --flac-root DIR PORTABLE_DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --flac-root=DIR       FLAC archive root (required)
#   --portable-root=DIR   Portable root (default: matching AUDIO_UTILS_ROOTS)
#   --exts=LIST           Master extensions to accept (default: flac)
#   -d                    Delete orphaned portable files
#
# -D / -y rejected.
# Exit codes: 0 clean, 1 orphans/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=16
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
