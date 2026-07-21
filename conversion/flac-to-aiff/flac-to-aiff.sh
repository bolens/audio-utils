#!/usr/bin/env bash
# Convert FLAC files to AIFF, with dual-decode MD5 verification.
#
# Usage:
#   flac-to-aiff.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-to-aiff.sh
#   convert-all.sh [options...]
#
# Options:
#   -f FILE     Read directory list from FILE
#   -d          Delete FLAC after successful conversion
#   -D          Cleanup only: delete FLACs that already have a valid sibling AIFF
#   -L FILE     Failure log
#   -S FILE     Success log CSV or .jsonl
#   -n          Dry run
#   -y          Overwrite existing AIFFs even if probe/MD5 pass
#   -j N        Parallel jobs
#   -q          Quiet
#   -v          Verbose
#   -h          Help
#   --version   Print version
#
# Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=23
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
