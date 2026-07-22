#!/usr/bin/env bash
# Extract audio from DVD VIDEO_TS directories to FLAC.
#
# Usage:
#   dvd-to-flac.sh /path/to/VIDEO_TS [/path/to/disc ...]
#   find-video_ts-dirs.sh | dvd-to-flac.sh
#   dvd-to-flac.sh -f list.txt
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -y  -q  -v  -h  --version
#   -j N     Accepted for CLI parity; DVD extract is serial (ignored)
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"

audio_utils_load_config

DIR_FILE=""
DRY_RUN=0
OVERWRITE=0
QUIET=0
VERBOSE=0
FAIL_LOG=""
SUCCESS_LOG=""
DELETE_SOURCE=0

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (($# > 0)); do
  case "$1" in
    -f) DIR_FILE=$2; shift 2 ;;
    -L) FAIL_LOG=$2; shift 2 ;;
    -S) SUCCESS_LOG=$2; shift 2 ;;
    -n) DRY_RUN=1; shift ;;
    -y) OVERWRITE=1; shift ;;
    -j) shift 2 ;; # accepted for CLI parity; DVD extract is serial
    -q) QUIET=1; shift ;;
    -v) VERBOSE=1; shift ;;
    -h|--help) usage 0 ;;
    --version) audio_utils_print_version "dvd-to-flac"; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage 2
      ;;
    *) break ;;
  esac
done

export DRY_RUN OVERWRITE DELETE_SOURCE QUIET VERBOSE
: "${FAIL_LOG:=$(audio_utils_state_dir dvd-to-flac)/failures.log}"
: "${SUCCESS_LOG:=$(audio_utils_state_dir dvd-to-flac)/success.csv}"
export FAIL_LOG SUCCESS_LOG

plugin_require_deps || exit 2
init_success_log || exit 2

PATHS=()
if [[ -n "$DIR_FILE" ]]; then
  mapfile -t PATHS <"$DIR_FILE"
fi
while (($# > 0)); do PATHS+=("$1"); shift; done
if ((${#PATHS[@]} == 0)) && [[ ! -t 0 ]]; then
  mapfile -t PATHS
fi
if ((${#PATHS[@]} == 0)); then
  echo "Error: no VIDEO_TS paths given" >&2
  usage 2
fi

ok=0
fail=0
idx=0
PROGRESS_TOTAL=${#PATHS[@]}
PROGRESS_START=$(date +%s)
export PROGRESS_TOTAL PROGRESS_START

for p in "${PATHS[@]}"; do
  [[ -z "${p// }" ]] && continue
  ((++idx))
  export PROGRESS_INDEX=$idx
  if convert_one "$p"; then ((ok++)) || true
  else ((fail++)) || true; fi
done

elapsed=$(( $(date +%s) - PROGRESS_START ))
log_always "Done. ok=$ok failed=$fail elapsed=$(fmt_dur "$elapsed")"
[[ "$fail" -eq 0 ]]
