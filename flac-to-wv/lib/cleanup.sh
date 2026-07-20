#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local wv="${flac%.*}.wv"
  if [[ ! -f "$wv" ]]; then
    log_progress "keep (no wv): $flac"
    return 0
  fi
  if ! is_wavpack_pure "$wv" || ! sibling_matches_source "$flac" "$wv"; then
    log_fail "$flac" "sibling wv hybrid/corrupt or MD5 mismatch" "wv=$wv"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (wv ok+md5)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (wv ok+md5)"
}
