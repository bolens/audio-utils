#!/usr/bin/env bash
# Cleanup mode: delete WAVs that already have a valid sibling FLAC.

delete_one_existing() {
  local wav="$1"
  local flac="${wav%.*}.flac"

  if [[ ! -f "$flac" ]]; then
    log_progress "keep (no flac): $wav"
    return 0
  fi

  if [[ ! -s "$flac" ]]; then
    log_fail "$wav" "sibling flac empty" "flac=$flac"
    return 1
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$wav" "sibling flac failed flac -t" "flac=$flac"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $wav (flac ok: $flac)"
    return 0
  fi

  rm -f -- "$wav"
  log_progress "deleted: $wav (flac ok: $flac)"
}
