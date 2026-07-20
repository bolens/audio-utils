#!/usr/bin/env bash
# Cleanup: delete AIFF/AIF that already have a valid sibling FLAC.

delete_one_existing() {
  local src="$1"
  local flac="${src%.*}.flac"

  if [[ ! -f "$flac" ]]; then
    log_progress "keep (no flac): $src"
    return 0
  fi

  if ! flac_ok "$flac"; then
    log_fail "$src" "sibling flac failed flac -t" "flac=$flac"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $src (flac ok: $flac)"
    return 0
  fi

  rm -f -- "$src"
  log_progress "deleted: $src (flac ok: $flac)"
}
