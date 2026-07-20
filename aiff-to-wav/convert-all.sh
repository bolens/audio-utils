#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/load.sh
source "${SCRIPT_DIR}/../lib/load.sh"
audio_utils_load_config
for _arg in "$@"; do case "$_arg" in --version) audio_utils_print_version "convert-all"; exit 0 ;; esac; done
list=$(audio_utils_mktemp "dirs.XXXXXX")
trap 'rm -f -- "$list"' EXIT
if ! "${SCRIPT_DIR}/find-aiff-dirs.sh" >"$list"; then exit 2; fi
[[ -s "$list" ]] || { echo "No AIFF directories found under configured roots." >&2; exit 0; }
"${SCRIPT_DIR}/aiff-to-wav.sh" "$@" <"$list"
