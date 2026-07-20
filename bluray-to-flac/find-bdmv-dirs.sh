#!/usr/bin/env bash
# List BDMV directories under roots.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/load.sh
source "${SCRIPT_DIR}/../lib/load.sh"
audio_utils_load_config

ROOTS=("$@")
if ((${#ROOTS[@]} == 0)); then
  raw="${AUDIO_UTILS_ROOTS:-}"
  [[ -n "$raw" ]] || { echo "Error: pass roots or set AUDIO_UTILS_ROOTS" >&2; exit 2; }
  # shellcheck disable=SC2206
  ROOTS=($raw)
fi

LC_ALL=C find -P "${ROOTS[@]}" -type d -iname 'BDMV' 2>/dev/null | LC_ALL=C sort -u
