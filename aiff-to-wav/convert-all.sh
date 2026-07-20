#!/usr/bin/env bash
# Find AIFF dirs and convert. Extra args are passed to aiff-to-wav.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/load.sh
source "${SCRIPT_DIR}/../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-aiff-dirs.sh" \
  "${SCRIPT_DIR}/aiff-to-wav.sh" \
  "AIFF" \
  "$@"
