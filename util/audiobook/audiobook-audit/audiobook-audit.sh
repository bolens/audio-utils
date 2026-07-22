#!/usr/bin/env bash
# audiobook-audit - QC for .m4b books and multi-file chapter dirs.
#
# Usage:
#   audiobook-audit.sh DIR [DIR ...]
#   find-audio-dirs.sh | audiobook-audit.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only (-d/-D/-y rejected). Checks cover, author, narrator, chapters,
# series consistency, and unexpected .m4b codecs.
# Exit codes: 0 ok, 1 issues found, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=13
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
