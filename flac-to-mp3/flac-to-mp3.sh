#!/usr/bin/env bash
# Convert FLAC files to MP3 in one or more directories, with verification.
#
# Verification (per file):
#   1. flac -t on source
#   2. Encode via libmp3lame (quality profile)
#   3. Probe audio stream; duration within ~50ms of source
#   4. Tags/cover mapped from FLAC
# Existing MP3s that probe OK are skipped; corrupt siblings are reconverted.
#
# Usage:
#   flac-to-mp3.sh DIR [DIR ...]
#   find-flac-dirs.sh | flac-to-mp3.sh
#   convert-all.sh [options...]
#
# Options:
#   -f FILE     Read directory list from FILE
#   -d          Delete FLAC after successful conversion
#   -D          Cleanup only: delete FLACs that already have a valid sibling MP3
#   -Q PROFILE  MP3 quality: v0 (default), v2, 320, 192
#   -N          No resample/downmix (fail on unsupported rate/channels)
#   -L FILE     Failure log (default: $XDG_STATE_HOME/audio-utils/flac-to-mp3/failures.log)
#   -S FILE     Success log CSV or .jsonl
#   -n          Dry run
#   -y          Overwrite existing MP3s even if probe passes
#   -j N        Parallel jobs (default: max(1, nproc/2))
#   -q          Quiet
#   -v          Verbose
#   -h          Help
#   --version   Print version
#   --quality P Same as -Q
#   --no-resample  Same as -N
#
# Quality also via FLAC2MP3_QUALITY or AUDIO_UTILS_MP3_QUALITY (default: v0).
#
# Exit codes: 0 all ok, 1 some failures, 2 usage/config/deps

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_USAGE_FILE="$0"
AU_USAGE_START=2
AU_USAGE_END=37
export AU_USAGE_FILE AU_USAGE_START AU_USAGE_END

# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"
# shellcheck source=../lib/driver.sh
source "${SCRIPT_DIR}/../lib/driver.sh"

audio_utils_load_config
audio_utils_run "$@"
