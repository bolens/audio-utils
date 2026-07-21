#!/usr/bin/env bash
# Read-only FLAC library audit (integrity, core tags, cover, leftover PCM).
#
# Usage:
#   flac-audit.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-audit.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Reports (fails the file) when:
#   - flac -t fails
#   - missing ARTIST / ALBUM / TITLE / TRACKNUMBER
#   - no embedded picture and no folder cover
#   - leftover sibling .wav / .aiff / .aif beside a FLAC
#
# Read-only: -d / -D / -y rejected.
# Exit codes: 0 all clean, 1 issues found, 2 usage/deps

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
