#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../../lib/find-audio-dirs.sh" \
  --ext mp3 --ext m4a --ext aac --ext opus --ext ogg --ext wma --ext mpc --ext spx "$@"
