#!/usr/bin/env bash
# Parallel worker: convert one WAV and print OK/FAIL.
# Usage: worker.sh INDEX TOTAL START_EPOCH WAV
# Expects flags via environment (DELETE_WAV, CLEAN_WAV, DRY_RUN, STATUS_DIR, …).
# Always writes STATUS_DIR/INDEX.status and prints exactly one OK|FAIL on stdout.

set -u

if (($# < 4)); then
  echo "usage: worker.sh INDEX TOTAL START_EPOCH WAV" >&2
  exit 2
fi

export PROGRESS_INDEX=$1
export PROGRESS_TOTAL=$2
export PROGRESS_START=$3
wav=$4
status=FAIL

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=load.sh
source "${SCRIPT_DIR}/lib/load.sh"

write_status() {
  local result=$1
  if [[ -n "${STATUS_DIR:-}" && -d "${STATUS_DIR}" ]]; then
    printf '%s\n' "$result" >"${STATUS_DIR}/${PROGRESS_INDEX}.status"
  fi
  printf '%s\n' "$result"
}

# Progress/logs → stderr; stdout is only OK/FAIL for xargs.
set +e
convert_one "$wav" >&2
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  status=OK
fi
write_status "$status"
exit 0
