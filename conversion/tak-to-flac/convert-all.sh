#!/usr/bin/env bash
# Find TAK dirs and convert. Extra args are passed to tak-to-flac.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../lib/load.sh
source "${SCRIPT_DIR}/../../lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/find-tak-dirs.sh" \
  "${SCRIPT_DIR}/tak-to-flac.sh" \
  "TAK" \
  "$@"
