#!/usr/bin/env bash
# List VIDEO_TS directories under roots.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_ROOT=$SCRIPT_DIR
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/load.sh
source "${AU_ROOT}/lib/load.sh"
audio_utils_load_config
ROOTS=()
PRINT0=0
audio_utils_parse_simple_find PRINT0 ROOTS "find-video_ts-dirs" \
  "List VIDEO_TS directories under roots." "$@" || exit $?
if ((PRINT0)); then
  find_named_dirs --print0 VIDEO_TS "${ROOTS[@]}"
else
  find_named_dirs VIDEO_TS "${ROOTS[@]}"
fi
