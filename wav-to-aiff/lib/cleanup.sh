#!/usr/bin/env bash
delete_one_existing() {
  local src="$1"
  local aiff="${src%.*}.aiff"
  if [[ ! -f "$aiff" ]]; then
    # also accept .aif sibling
    aiff="${src%.*}.aif"
  fi
  if [[ ! -f "$aiff" ]]; then
    log_progress "keep (no aiff): $src"
    return 0
  fi
  if ! pcm_ok "$aiff" || ! sibling_matches_source "$src" "$aiff"; then
    log_fail "$src" "sibling aiff not ok or MD5 mismatch" "aiff=$aiff"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $src (aiff ok+md5: $aiff)"
    return 0
  fi
  rm -f -- "$src"
  log_progress "deleted: $src (aiff ok+md5: $aiff)"
}
