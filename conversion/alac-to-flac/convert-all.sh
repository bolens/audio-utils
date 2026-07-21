#!/usr/bin/env bash
# Find M4A/ALAC dirs and convert. Extra args are passed to alac-to-flac.sh.
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
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-m4a-dirs.sh" \
  "${SCRIPT_DIR}/alac-to-flac.sh" \
  "M4A/ALAC" \
  "$@"
