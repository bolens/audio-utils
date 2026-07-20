#!/usr/bin/env bash
delete_one_existing() {
  local flac="$1"
  local ape="${flac%.*}.ape"
  if [[ ! -f "$ape" ]]; then
    log_progress "keep (no ape): $flac"
    return 0
  fi
  if [[ "$(audio_codec "$ape" 2>/dev/null || true)" != "ape" ]] || ! sibling_matches_source "$flac" "$ape"; then
    log_fail "$flac" "sibling ape not ok or MD5 mismatch" "ape=$ape"
    return 1
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (ape ok+md5: $ape)"
    return 0
  fi
  rm -f -- "$flac"
  log_progress "deleted: $flac (ape ok+md5: $ape)"
}
