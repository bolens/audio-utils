#!/usr/bin/env bash
# Cleanup: delete FLACs that already have a valid sibling AIFF (probe + MD5).

delete_one_existing() {
  local flac="$1"
  local aiff="${flac%.*}.aiff"

  if [[ ! -f "$aiff" ]]; then
    log_progress "keep (no aiff): $flac"
    return 0
  fi

  if ! pcm_ok "$aiff" || ! sibling_matches_source "$flac" "$aiff"; then
    log_fail "$flac" "sibling aiff missing/corrupt or MD5 mismatch" "aiff=$aiff"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (aiff ok+md5: $aiff)"
    return 0
  fi

  rm -f -- "$flac"
  log_progress "deleted: $flac (aiff ok+md5: $aiff)"
}
