#!/usr/bin/env bash
delete_one_existing() {
  local src="$1"
  local wav="${src%.*}.wav"
  if [[ ! -f "$wav" ]]; then
    log_progress "keep (no wav): $src"
    return 0
  fi
  if ! pcm_ok "$wav" || ! sibling_matches_source "$src" "$wav"; then
    log_fail "$src" "sibling wav not ok or MD5 mismatch" "wav=$wav"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $src (wav ok+md5: $wav)"
    return 0
  fi
  rm -f -- "$src"
  log_progress "deleted: $src (wav ok+md5: $wav)"
}
