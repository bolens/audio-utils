#!/usr/bin/env bash
# Cleanup: delete FLACs that already have a valid sibling MP3.

delete_one_existing() {
  local flac="$1"
  local mp3="${flac%.*}.mp3"

  if [[ ! -f "$mp3" ]]; then
    log_progress "keep (no mp3): $flac"
    return 0
  fi

  if ! mp3_ok "$mp3"; then
    log_fail "$flac" "sibling mp3 missing/corrupt" "mp3=$mp3"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (mp3 ok: $mp3)"
    return 0
  fi

  rm -f -- "$flac"
  log_progress "deleted: $flac (mp3 ok: $mp3)"
}
