#!/usr/bin/env bash
# Find DSD dirs and convert. Extra args are passed to dsf-to-flac.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-dsd-dirs.sh" \
  "${SCRIPT_DIR}/dsf-to-flac.sh" \
  "DSD" \
  "$@"
