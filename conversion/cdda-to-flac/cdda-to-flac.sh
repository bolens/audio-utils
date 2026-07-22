#!/usr/bin/env bash
# Rip audio CD → FLAC via cdparanoia.
#
# Usage:
#   cdda-to-flac.sh [DEVICE] [-o OUTDIR]
#   cdda-to-flac.sh -n                 # list tracks
#
# Options:
#   -o DIR      Output directory (default: ./cdda-rip)
#   -d DEVICE   CD device (default: AUDIO_UTILS_CD_DEVICE, CDDA_DEVICE, or /dev/sr0)
#   -L FILE  -S FILE  -n  -y  -q  -v  -h  --version
#   -j N        Accepted for CLI parity; CDDA rip is serial (ignored)
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/plugin.sh
source "${SCRIPT_DIR}/lib/plugin.sh"

audio_utils_load_config

DEVICE="${AUDIO_UTILS_CD_DEVICE:-${CDDA_DEVICE:-/dev/sr0}}"
OUTDIR="${CDDA_OUTDIR:-./cdda-rip}"
DRY_RUN=0
OVERWRITE=0
QUIET=0
VERBOSE=0
FAIL_LOG=""
SUCCESS_LOG=""

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (($# > 0)); do
  case "$1" in
    -o) OUTDIR=$2; shift 2 ;;
    -d) DEVICE=$2; shift 2 ;;
    -L) FAIL_LOG=$2; shift 2 ;;
    -S) SUCCESS_LOG=$2; shift 2 ;;
    -n) DRY_RUN=1; shift ;;
    -y) OVERWRITE=1; shift ;;
    -j) shift 2 ;; # accepted for CLI parity; CDDA rip is serial
    -q) QUIET=1; shift ;;
    -v) VERBOSE=1; shift ;;
    -h|--help) usage 0 ;;
    --version) audio_utils_print_version "cdda-to-flac"; exit 0 ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage 2
      ;;
    *)
      DEVICE=$1
      shift
      ;;
  esac
done

export DRY_RUN OVERWRITE QUIET VERBOSE
export CDDA_OUTDIR="$OUTDIR"
: "${FAIL_LOG:=$(audio_utils_state_dir cdda-to-flac)/failures.log}"
: "${SUCCESS_LOG:=$(audio_utils_state_dir cdda-to-flac)/success.csv}"
export FAIL_LOG SUCCESS_LOG

plugin_require_deps || exit 2
init_success_log || exit 2

count=$(cdda_track_count "$DEVICE") || exit 2
log_always "CDDA device: $DEVICE  tracks: $count  out: $OUTDIR"

ok=0
fail=0
PROGRESS_TOTAL=$count
PROGRESS_START=$(date +%s)
export PROGRESS_TOTAL PROGRESS_START

for ((t = 1; t <= count; t++)); do
  export PROGRESS_INDEX=$t
  syn="${DEVICE}#${t}"
  if convert_one "$syn"; then ((ok++)) || true
  else ((fail++)) || true; fi
done

elapsed=$(( $(date +%s) - PROGRESS_START ))
log_always "Done. ok=$ok failed=$fail elapsed=$(fmt_dur "$elapsed")"
[[ "$fail" -eq 0 ]]
