#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_ROOT=$SCRIPT_DIR
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || exit 2
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/load.sh
source "${AU_ROOT}/lib/load.sh"
audio_utils_load_config
audio_utils_convert_all "${SCRIPT_DIR}/find-archive-dirs.sh" \
  "${SCRIPT_DIR}/archive-audit.sh" "archive packages" "$@"
