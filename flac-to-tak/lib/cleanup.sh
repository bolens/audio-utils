#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local tak="${flac%.*}.tak"
  if [[ ! -f "$tak" ]]; then
    log_progress "keep (no tak): $flac"
    return 0
  fi
  if ! sibling_matches_source "$flac" "$tak"; then
    log_fail "$flac" "sibling tak MD5 mismatch" "tak=$tak"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (tak ok+md5: $tak)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (tak ok+md5: $tak)"
}
