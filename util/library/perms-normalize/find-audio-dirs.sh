#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_ROOT=$SCRIPT_DIR
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
exec "${AU_ROOT}/lib/cli/find-audio-dirs.sh" \
  --ext flac -e mp3 -e opus -e m4a -e ogg -e oga -e wma -e mpc -e spx -e aac \
  -e wav -e aiff -e aif -e caf -e wv -e ape -e tak -e tta \
  -e cue -e m3u -e m3u8 -e pls -e xspf -e jpg -e jpeg -e png -e log "$@"
