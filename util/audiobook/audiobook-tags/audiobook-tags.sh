#!/usr/bin/env bash
# audiobook-tags - normalize author/narrator/series tags for audiobooks.
#
# Usage:
#   audiobook-tags.sh DIR [DIR ...]
#   find-audio-dirs.sh | audiobook-tags.sh
#
# Options:
#   --apply            Write normalized tags (default: report only)
#   --all-genres       Do not skip non-audiobook genres
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# -d / -D / -y rejected (use --apply). Default scope: audiobook-ish GENRE,
# existing narrator/series/ASIN/ISBN, or .m4b.
# Exit codes: 0 ok, 1 needs work, 2 usage/deps

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
