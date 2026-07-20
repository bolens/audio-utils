#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local out="${flac%.*}.ogg"
  if [[ ! -f "$out" ]]; then
    log_progress "keep (no ogg): $flac"
    return 0
  fi
  if ! ogg_ok "$out"; then
    log_fail "$flac" "sibling ogg missing/corrupt" "ogg=$out"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (ogg ok: $out)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (ogg ok: $out)"
}
