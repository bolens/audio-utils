#!/usr/bin/env bash
# Cleanup mode: delete FLACs that already have a valid sibling WAV.

delete_one_existing() {
  local flac="$1"
  local wav="${flac%.*}.wav"

  if [[ ! -f "$wav" ]]; then
    log_progress "keep (no wav): $flac"
    return 0
  fi

  if ! wav_ok "$wav" || ! sibling_matches_source "$flac" "$wav"; then
    log_fail "$flac" "sibling wav missing/corrupt or MD5 mismatch" "wav=$wav"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $flac (wav ok+md5: $wav)"
    return 0
  fi

  rm -f -- "$flac"
  log_progress "deleted: $flac (wav ok+md5: $wav)"
}
