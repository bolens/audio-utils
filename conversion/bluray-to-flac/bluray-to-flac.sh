#!/usr/bin/env bash
# Extract Blu-ray / BDMV / decrypted M2TS|MKV audio -> FLAC.
#
# Usage:
#   bluray-to-flac.sh /path/to/BDMV [/path/to/disc ...]
#   bluray-to-flac.sh /path/to/decrypted.m2ts
#   bluray-to-flac.sh -D /dev/sr0
#   find-bdmv-dirs.sh | bluray-to-flac.sh
#
# Options:
#   -D DEVICE  Blu-ray device (default: AUDIO_UTILS_BD_DEVICE or /dev/sr0)
#   -f FILE  -L FILE  -S FILE  -n  -y  -q  -v  -h  --version
#   -j N       Accepted for CLI parity; extract is serial per title (ignored)
#
# Hybrid: uses libbluray+libaacs (+ operator KEYDB) or MakeMKV when present;
# otherwise accepts already-decrypted media. No keys shipped in-repo.
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
BD_DEVICE=""

usage() {
      sed -n '2,18p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (($# > 0)); do
  case "$1" in
    -D)
      [[ $# -ge 2 ]] || { echo "Error: -D needs a device" >&2; usage 2; }
      BD_DEVICE=$2
      shift 2
      ;;
    -f) DIR_FILE=$2; shift 2 ;;
    -L) FAIL_LOG=$2; shift 2 ;;
    -S) SUCCESS_LOG=$2; shift 2 ;;
    -n) DRY_RUN=1; shift ;;
    -y) OVERWRITE=1; shift ;;
    -j) shift 2 ;; # accepted for CLI parity; extract is serial per title
    -q) QUIET=1; shift ;;
    -v) VERBOSE=1; shift ;;
    -h|--help) usage 0 ;;
    --version) audio_utils_print_version "bluray-to-flac"; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage 2
      ;;
    *) break ;;
  esac
done

if [[ -n "$BD_DEVICE" ]]; then
  AUDIO_UTILS_BD_DEVICE="$BD_DEVICE"
  export AUDIO_UTILS_BD_DEVICE
fi

export DRY_RUN OVERWRITE DELETE_SOURCE QUIET VERBOSE
: "${FAIL_LOG:=$(audio_utils_state_dir bluray-to-flac)/failures.log}"
: "${SUCCESS_LOG:=$(audio_utils_state_dir bluray-to-flac)/success.csv}"
export FAIL_LOG SUCCESS_LOG

plugin_require_deps || exit 2
init_success_log || exit 2

PATHS=()
if [[ -n "$DIR_FILE" ]]; then
  mapfile -t PATHS <"$DIR_FILE"
fi
while (($# > 0)); do PATHS+=("$1"); shift; done

# -D alone: rip from device
if [[ -n "$BD_DEVICE" ]] && ((${#PATHS[@]} == 0)); then
  PATHS+=("$BD_DEVICE")
fi

if ((${#PATHS[@]} == 0)) && [[ ! -t 0 ]]; then
  mapfile -t PATHS
fi
if ((${#PATHS[@]} == 0)); then
  echo "Error: no BDMV paths, media, or -D device given" >&2
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
