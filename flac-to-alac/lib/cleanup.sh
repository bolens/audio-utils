#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local m4a="${flac%.*}.m4a"
  if [[ ! -f "$m4a" ]]; then
    log_progress "keep (no m4a): $flac"
    return 0
  fi
  if ! is_alac "$m4a" || ! sibling_matches_source "$flac" "$m4a"; then
    log_fail "$flac" "sibling m4a not alac or MD5 mismatch" "m4a=$m4a"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (alac ok+md5: $m4a)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (alac ok+md5: $m4a)"
}
