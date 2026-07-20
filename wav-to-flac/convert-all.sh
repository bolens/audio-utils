#!/usr/bin/env bash
# Find WAV dirs and convert them. Extra args are passed to wav-to-flac.sh.
#
# Roots via AUDIO_UTILS_ROOTS, WAV2FLAC_ROOTS, or
#   ${XDG_CONFIG_HOME:-~/.config}/audio-utils/config
#
# Examples:
#   ./convert-all.sh -n
#   ./convert-all.sh -q -j 4
#   ./convert-all.sh --version
#
# Exit codes: same as wav-to-flac / find (0 ok, 1 convert failures, 2 usage/config)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/load.sh
source "${SCRIPT_DIR}/../lib/load.sh"
audio_utils_load_config

for _arg in "$@"; do
  case "$_arg" in
    --version)
      audio_utils_print_version "convert-all"
      exit 0
      ;;
  esac
done

list=$(audio_utils_mktemp "dirs.XXXXXX")
cleanup_list() { rm -f -- "$list"; }
trap cleanup_list EXIT

if ! "${SCRIPT_DIR}/find-wav-dirs.sh" >"$list"; then
  exit 2
fi

if [[ ! -s "$list" ]]; then
  echo "No WAV directories found under configured roots." >&2
  exit 0
fi

# Avoid pipefail/exec pitfalls: feed the list on stdin explicitly.
"${SCRIPT_DIR}/wav-to-flac.sh" "$@" <"$list"
