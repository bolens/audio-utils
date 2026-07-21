#!/usr/bin/env bash
# Compare each scanned file to the same relative path under --against.

convert_one() {
  local src="$1" root rel other a_bytes b_bytes a_sha b_sha
  local -a roots=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would diff: $src"; return 0
  fi

  if audio_utils_roots_from_env roots; then
    local r abs
    abs=$(au_abspath "$src")
    for r in "${roots[@]}"; do
      r=$(cd -- "$r" 2>/dev/null && pwd) || continue
      case "$abs" in
        "$r"/*) root=$r; break ;;
      esac
    done
  fi
  # Fallback: parent of file's album dir's parent is unreliable — use dirname walk
  if [[ -z "${root:-}" ]]; then
    # Use the directory argument's common ancestor: file's path relative to cwd roots
    log_fail "$src" "cannot resolve source root (set AUDIO_UTILS_ROOTS)"
    return 1
  fi

  if ! rel=$(audio_relpath_under "$root" "$src"); then
    log_fail "$src" "not under root $root"; return 1
  fi
  other="${DIFF_AGAINST}/${rel}"
  if [[ ! -f "$other" ]]; then
    log_fail "$src" "missing in against tree" "expected=$other"
    return 1
  fi

  a_bytes=$(file_bytes "$src")
  b_bytes=$(file_bytes "$other")
  if [[ "$a_bytes" != "$b_bytes" ]]; then
    log_fail "$src" "size mismatch" "here=$a_bytes against=$b_bytes"
    return 1
  fi

  if [[ "${DIFF_HASH:-0}" -eq 1 ]]; then
    a_sha=$(file_sha256 "$src")
    b_sha=$(file_sha256 "$other")
    if [[ "$a_sha" != "$b_sha" ]]; then
      log_fail "$src" "sha256 mismatch" "against=$other"
      return 1
    fi
  fi

  log_progress "match: $rel"
  log_success "$src" "match" "" "$(file_sha256 "$src")" "against-ok"
}
