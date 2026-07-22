#!/usr/bin/env bash
# Find empty directories under roots (deepest first so parents empty after -d).
#
# Usage:
#   find-empty-dirs.sh [ROOT ...]
#
# Roots: args, else AUDIO_UTILS_ROOTS / config (via shared loader).
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_ROOT=$SCRIPT_DIR
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/load.sh
source "${AU_ROOT}/lib/load.sh"
audio_utils_load_config

ROOTS=("$@")
if ((${#ROOTS[@]} == 0)); then
  cfg=()
  if audio_utils_roots_from_env cfg && ((${#cfg[@]} > 0)); then
    ROOTS=("${cfg[@]}")
  else
    echo "Error: no roots (pass dirs or set AUDIO_UTILS_ROOTS)" >&2
    exit 2
  fi
fi

FIND_BIN=$(au_find_bin)
for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  # Deepest paths first so -d can clear parents in a later pass / same run order.
  LC_ALL=C "$FIND_BIN" -P "$root" -depth -type d -empty -printf '%p\n'
done | LC_ALL=C sort -r
