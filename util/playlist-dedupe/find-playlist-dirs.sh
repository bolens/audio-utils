#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../../lib/find-audio-dirs.sh" \
  --ext m3u -e m3u8 -e pls -e xspf "$@"
