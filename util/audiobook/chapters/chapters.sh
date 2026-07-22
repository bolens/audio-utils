#!/usr/bin/env bash
# chapters - list / extract / embed chapter markers on .m4b / .m4a.
#
# Usage:
#   chapters.sh DIR [DIR ...]
#   find-m4b-dirs.sh | chapters.sh
#
# Options:
#   --extract=FILE   Write ffmetadata chapters to FILE
#   --embed=FILE     Apply ffmetadata from FILE (requires --apply or -y)
#   --apply          Allow --embed to rewrite the container
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# -d / -D rejected. Default: list chapters.
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
