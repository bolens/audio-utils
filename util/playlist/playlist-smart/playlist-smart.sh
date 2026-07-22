#!/usr/bin/env bash
# playlist-smart - build a filtered .m3u from tag queries.
#
# Usage:
#   playlist-smart.sh --out FILE --genre Rock DIR [DIR ...]
#   find-flac-dirs.sh | playlist-smart.sh --out ~/playlists/rock.m3u --genre Rock
#
# Options:
#   --out PATH         Destination .m3u (required)
#   --genre SUBSTR     Case-insensitive GENRE substring
#   --artist SUBSTR    Case-insensitive ARTIST/ALBUMARTIST substring
#   --key VALUE        Exact INITIALKEY / KEY (spaces ignored)
#   --bpm-min N        Minimum BPM
#   --bpm-max N        Maximum BPM
#   --rg-max N         Max REPLAYGAIN_TRACK_GAIN (dB; louder tracks excluded)
#   --relative         Write paths relative to the playlist directory
#   -y                 Overwrite existing --out
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# At least one filter is required. -d/-D rejected.
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=21
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
