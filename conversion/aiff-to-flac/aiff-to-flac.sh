#!/usr/bin/env bash
# Convert AIFF/AIF files to FLAC in one or more directories, with verification.
#
# Same verification bar as wav-to-flac (remux, dual encode, e2e MD5, tags).
#
# Usage:
#   aiff-to-flac.sh DIR [DIR ...]
#   find-aiff-dirs.sh | aiff-to-flac.sh
#   convert-all.sh [options...]
#
# Options:
#   -f FILE     Read directory list from FILE
#   -d          Delete AIFF after successful conversion
#   -D          Cleanup only: delete AIFFs that already have a sibling FLAC
#   -c          Replace AIFF with a clean decode from the verified FLAC
#   -R          Retag only: copy metadata/cover onto existing valid FLACs
#   -L FILE     Failure log
#   -S FILE     Success log CSV or .jsonl
#   -n          Dry run
#   -y          Overwrite existing FLACs even if flac -t passes
#   -j N        Parallel jobs
#   -q          Quiet
#   -v          Verbose
#   -h          Help
#   --version   Print version
#
# Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=27
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
