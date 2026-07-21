#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "${SCRIPT_DIR}/../../lib/find-audio-dirs.sh" \
  --ext db -e ini -e ds_store -e directory \
  -e flac -e mp3 -e opus -e m4a -e ogg -e oga -e wma -e mpc -e aac \
  -e wav -e aiff -e aif -e caf -e wv -e ape -e tak -e tta \
  -e cue -e m3u -e m3u8 -e pls -e xspf -e jpg -e jpeg -e png -e log "$@"
