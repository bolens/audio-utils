#!/usr/bin/env bash
# Package version helpers.

audio_utils_version() {
  local f="${_AUDIO_UTILS_LIB_DIR}/../VERSION"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' <"$f"
  else
    printf '%s\n' '0.0.0-dev'
  fi
}

audio_utils_print_version() {
  local tool="${1:-audio-utils}"
  printf '%s (audio-utils) %s\n' "$tool" "$(audio_utils_version)"
}
