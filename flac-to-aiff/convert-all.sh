#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/load.sh
source "${SCRIPT_DIR}/../lib/load.sh"
audio_utils_load_config
for _arg in "$@"; do
  case "$_arg" in
    --version) audio_utils_print_version "convert-all"; exit 0 ;;
  esac
done
list=$(audio_utils_mktemp "dirs.XXXXXX")
cleanup_list() { rm -f -- "$list"; }
trap cleanup_list EXIT
if ! "${SCRIPT_DIR}/find-flac-dirs.sh" >"$list"; then exit 2; fi
if [[ ! -s "$list" ]]; then
  echo "No FLAC directories found under configured roots." >&2
  exit 0
fi
"${SCRIPT_DIR}/flac-to-aiff.sh" "$@" <"$list"
