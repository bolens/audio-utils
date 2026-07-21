#!/usr/bin/env bash
# Generic parallel worker for audio-utils tools.
# Usage: worker.sh INDEX TOTAL START_EPOCH SOURCE_PATH
# Requires AU_TOOL_DIR pointing at the tool root (contains lib/plugin.sh).

set -u

if (($# < 4)); then
  echo "usage: worker.sh INDEX TOTAL START_EPOCH SOURCE" >&2
  exit 2
fi

export PROGRESS_INDEX=$1
export PROGRESS_TOTAL=$2
export PROGRESS_START=$3
src=$4
status=FAIL

if [[ -z "${AU_TOOL_DIR:-}" || ! -f "${AU_TOOL_DIR}/lib/plugin.sh" ]]; then
  echo "Error: AU_TOOL_DIR must point at a tool with lib/plugin.sh" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "${AU_TOOL_DIR}/lib/plugin.sh"

write_status() {
  local result=$1
  if [[ -n "${STATUS_DIR:-}" && -d "${STATUS_DIR}" ]]; then
    printf '%s\n' "$result" >"${STATUS_DIR}/${PROGRESS_INDEX}.status"
  fi
  printf '%s\n' "$result"
}

set +e
convert_one "$src" >&2
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  status=OK
fi
write_status "$status"
exit 0
