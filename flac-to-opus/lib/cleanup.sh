#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local out="${flac%.*}.opus"
  if [[ ! -f "$out" ]]; then
    log_progress "keep (no opus): $flac"
    return 0
  fi
  if ! opus_ok "$out"; then
    log_fail "$flac" "sibling opus missing/corrupt" "opus=$out"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (opus ok: $out)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (opus ok: $out)"
}
