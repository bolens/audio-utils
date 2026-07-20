#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local out="${flac%.*}.m4a"
  if [[ ! -f "$out" ]]; then
    log_progress "keep (no m4a): $flac"
    return 0
  fi
  if ! m4a_ok "$out"; then
    log_fail "$flac" "sibling m4a missing/corrupt" "m4a=$out"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (m4a ok: $out)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (m4a ok: $out)"
}
