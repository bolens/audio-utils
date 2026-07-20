#!/usr/bin/env bash
# Shared convert-all runner.
#
# Usage from a tool's convert-all.sh:
#   audio_utils_convert_all FIND_SCRIPT CONVERT_SCRIPT EMPTY_LABEL "$@"
#
# Example:
#   audio_utils_convert_all \
#     "${SCRIPT_DIR}/find-flac-dirs.sh" \
#     "${SCRIPT_DIR}/flac-to-mp3.sh" \
#     "FLAC" \
#     "$@"

audio_utils_convert_all() {
  local find_script=$1 convert_script=$2 empty_label=$3
  local list
  shift 3

  for _arg in "$@"; do
    case "$_arg" in
      --version)
        audio_utils_print_version "convert-all"
        return 0
        ;;
    esac
  done

  list=$(audio_utils_mktemp "dirs.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f -- '$list'" EXIT

  if ! "$find_script" >"$list"; then
    return 2
  fi

  if [[ ! -s "$list" ]]; then
    echo "No ${empty_label} directories found under configured roots." >&2
    return 0
  fi

  "$convert_script" "$@" <"$list"
}
