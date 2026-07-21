#!/usr/bin/env bash
# For each portable file, require a master under --flac-root; report/delete
# orphans.

_prune_portable_root_for() {
  local f=$1
  if [[ -n "${PRUNE_PORTABLE_ROOT:-}" ]]; then
    printf '%s\n' "$PRUNE_PORTABLE_ROOT"
    return 0
  fi
  local -a roots=()
  local r abs
  if audio_utils_roots_from_env roots; then
    abs=$(au_abspath "$f")
    for r in "${roots[@]}"; do
      r=$(cd -- "$r" 2>/dev/null && pwd) || continue
      case "$abs" in
        "$r"/*)
          printf '%s\n' "$r"
          return 0
          ;;
      esac
    done
  fi
  return 1
}

convert_one() {
  local f="$1" root rel stem ext found=""
  local -a exts

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would prune-check: $f"; return 0
  fi

  root=$(_prune_portable_root_for "$f") || {
    log_fail "$f" "cannot resolve portable root (use --portable-root or AUDIO_UTILS_ROOTS)"
    return 1
  }

  if ! rel=$(audio_relpath_under "$root" "$f"); then
    log_fail "$f" "not under portable root $root"
    return 1
  fi

  stem=${rel%.*}
  # shellcheck disable=SC2206
  exts=(${PRUNE_MASTER_EXTS:-flac})
  for ext in "${exts[@]}"; do
    if [[ -f "${PRUNE_FLAC_ROOT:?}/${stem}.${ext}" ]]; then
      found="${PRUNE_FLAC_ROOT}/${stem}.${ext}"
      break
    fi
  done

  if [[ -n "$found" ]]; then
    log_progress "ok: $f (master: $(basename -- "$found"))"
    log_success "$f" "kept" "" "" "master=$(basename -- "$found")"
    return 0
  fi

  if [[ "${PRUNE_DELETE:-0}" -eq 1 ]]; then
    if ! rm -f -- "$f"; then
      log_fail "$f" "delete failed"
      return 1
    fi
    log_progress "deleted orphan: $f"
    log_success "$f" "deleted" "" "" "no-master"
    return 0
  fi

  log_fail "$f" "orphaned portable file (no master)" \
    "looked=${PRUNE_MASTER_EXTS} under=${PRUNE_FLAC_ROOT}/${stem}.*"
  return 1
}
