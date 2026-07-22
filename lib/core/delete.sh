#!/usr/bin/env bash
# Generic -D cleanup: delete source when a valid sibling destination exists.
#
# Requires: AU_DEST_EXT
# Optional:
#   AU_CLEANUP_SKIP=1          — no-op for -D (disc extractors; streams still
#                                honors -d for container delete). Prefer reject
#                                in plugin_after_flags when -D is unsupported.
#   plugin_sibling_ok SRC DEST — verify sibling; default = dest has audio stream
#
# Tools may override delete_one_existing entirely if needed.

# Default sibling check: non-empty file with a readable audio stream.
sibling_ok_default() {
  local _src="$1" dest="$2"
  [[ -f "$dest" && -s "$dest" ]] || return 1
  [[ -n "$(audio_codec "$dest")" ]]
}

# True if DEST is a valid sibling of SRC for -D cleanup.
sibling_ok() {
  local src="$1" dest="$2"
  if declare -F plugin_sibling_ok >/dev/null 2>&1; then
    plugin_sibling_ok "$src" "$dest"
    return $?
  fi
  sibling_ok_default "$src" "$dest"
}

delete_one_existing() {
  local src="$1"
  local dest_ext="${AU_DEST_EXT:-}"
  local dest label

  if [[ "${AU_CLEANUP_SKIP:-0}" -eq 1 ]]; then
    log_progress "cleanup skip (${AU_TOOL_NAME:-tool}): $src"
    return 0
  fi

  [[ -n "$dest_ext" ]] || {
    log_fail "$src" "AU_DEST_EXT unset for cleanup"
    return 1
  }

  dest="${src%.*}.${dest_ext}"
  label=$dest_ext

  if [[ ! -f "$dest" ]]; then
    log_progress "keep (no ${label}): $src"
    return 0
  fi

  if ! sibling_ok "$src" "$dest"; then
    log_fail "$src" "sibling ${label} missing/corrupt or verify failed" "${label}=$dest"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would delete: $src (${label} ok: $dest)"
    return 0
  fi

  rm -f -- "$src"
  log_progress "deleted: $src (${label} ok: $dest)"
}
