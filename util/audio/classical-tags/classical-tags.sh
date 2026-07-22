#!/usr/bin/env bash
# classical-tags - normalize classical role tags (COMPOSER/WORK/MOVEMENT/…).
#
# Usage:
#   classical-tags.sh DIR [DIR ...]
#   find-audio-dirs.sh | classical-tags.sh
#
# Options:
#   --apply            Write normalized tags (default: report only)
#   --require-roles    Fail when COMPOSER is missing on classical tracks
#   --all-genres       Do not skip non-classical genres
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# -d / -D / -y rejected (use --apply). Default scope: classical-ish GENRE
# or existing COMPOSER/WORK tags.
# Exit codes: 0 ok, 1 needs work, 2 usage/deps

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
