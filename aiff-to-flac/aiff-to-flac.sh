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

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_USAGE_FILE="$0"
AU_USAGE_START=2
AU_USAGE_END=27
export AU_USAGE_FILE AU_USAGE_START AU_USAGE_END

# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"
# shellcheck source=../lib/driver.sh
source "${SCRIPT_DIR}/../lib/driver.sh"

audio_utils_load_config
audio_utils_run "$@"
