#!/usr/bin/env bash
# Find TTA dirs and convert. Extra args are passed to tta-to-flac.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-tta-dirs.sh" \
  "${SCRIPT_DIR}/tta-to-flac.sh" \
  "TTA" \
  "$@"
