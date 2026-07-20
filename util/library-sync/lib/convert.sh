#!/usr/bin/env bash
# For each FLAC, require at least one portable sibling under --portable-root.

convert_one() {
  local flac="$1" rel stem ext found="" candidate flac_root
  local -a exts

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would sync-check: $flac"; return 0
  fi

  flac_root="${SYNC_FLAC_ROOT:-}"
  if [[ -z "$flac_root" ]]; then
    # Infer: walk up until under portable is meaningless — use dirname chain
    # Prefer: relative to first matching AUDIO_UTILS_ROOTS entry
    local -a roots=()
    if audio_utils_roots_from_env roots; then
      local r abs
      abs=$(readlink -f -- "$flac" 2>/dev/null || printf '%s' "$flac")
      for r in "${roots[@]}"; do
        r=$(cd -- "$r" 2>/dev/null && pwd) || continue
        case "$abs" in
          "$r"/*) flac_root=$r; break ;;
        esac
      done
    fi
  fi
  if [[ -z "$flac_root" ]]; then
    log_fail "$flac" "cannot resolve FLAC library root (set AUDIO_UTILS_ROOTS)"
    return 1
  fi

  if ! rel=$(audio_relpath_under "$flac_root" "$flac"); then
    log_fail "$flac" "not under FLAC root $flac_root"
    return 1
  fi

  stem=${rel%.*}
  # shellcheck disable=SC2206
  exts=(${SYNC_EXTS})
  for ext in "${exts[@]}"; do
    candidate="${SYNC_PORTABLE_ROOT}/${stem}.${ext}"
    if [[ -f "$candidate" ]]; then
      found=$candidate
      break
    fi
  done

  if [[ -z "$found" ]]; then
    log_fail "$flac" "missing portable sibling" "looked=${SYNC_EXTS} under=${SYNC_PORTABLE_ROOT}/${stem}.*"
    return 1
  fi

  log_progress "ok: $flac → $(basename -- "$found")"
  log_success "$flac" "synced" "" "$(file_sha256 "$flac")" "sibling=$(basename -- "$found")"
}
