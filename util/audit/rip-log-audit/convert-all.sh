#!/usr/bin/env bash
# Find log dirs and run rip-log-audit. Extra args go to rip-log-audit.sh.
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
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-log-dirs.sh" \
  "${SCRIPT_DIR}/rip-log-audit.sh" \
  "log" \
  "$@"
