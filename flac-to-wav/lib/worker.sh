#!/usr/bin/env bash
# Parallel worker: convert one FLAC → WAV.
# Usage: worker.sh INDEX TOTAL START_EPOCH FLAC

set -u

if (($# < 4)); then
  echo "usage: worker.sh INDEX TOTAL START_EPOCH FLAC" >&2
  exit 2
fi

export PROGRESS_INDEX=$1
export PROGRESS_TOTAL=$2
export PROGRESS_START=$3
flac=$4
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

set +e
convert_one "$flac" >&2
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  status=OK
fi
write_status "$status"
exit 0
