#!/usr/bin/env bash
# Compare one audio file to the same relative path under --against.

_compare_resolve_other() {
  local src=$1 root rel
  local -a roots=()

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
  if [[ -z "${root:-}" ]]; then
    return 1
  fi
  rel=$(audio_relpath_under "$root" "$src") || return 1
  printf '%s\n' "${COMPARE_AGAINST}/${rel}"
}

_compare_streaminfo_md5() {
  local f=$1
  local m
  m=$(metaflac --show-md5sum -- "$f" 2>/dev/null) || return 1
  m=${m,,}
  [[ -n "$m" && "$m" != "00000000000000000000000000000000" ]] || return 1
  printf '%s\n' "$m"
}

convert_one() {
  local src="$1" other a b pa pb delta

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would compare (${COMPARE_MODE}): $src"
    return 0
  fi

  if ! other=$(_compare_resolve_other "$src"); then
    log_fail "$src" "cannot resolve source root (set AUDIO_UTILS_ROOTS)"
    return 1
  fi
  if [[ ! -f "$other" ]]; then
    log_fail "$src" "missing against file" "expected=$other"
    return 1
  fi

  case "${COMPARE_MODE}" in
    md5)
      a=$(audio_md5 "$src") || true
      b=$(audio_md5 "$other") || true
      if [[ -z "$a" || -z "$b" ]]; then
        log_fail "$src" "decode MD5 failed" "against=$other"
        return 1
      fi
      if [[ "$a" != "$b" ]]; then
        log_fail "$src" "audio MD5 mismatch" "here=$a against=$b"
        return 1
      fi
      ;;
    streaminfo)
      if [[ "${src,,}" != *.flac || "${other,,}" != *.flac ]]; then
        log_fail "$src" "streaminfo mode requires FLAC on both sides"
        return 1
      fi
      a=$(_compare_streaminfo_md5 "$src") || {
        log_fail "$src" "no STREAMINFO MD5"
        return 1
      }
      b=$(_compare_streaminfo_md5 "$other") || {
        log_fail "$src" "against has no STREAMINFO MD5" "against=$other"
        return 1
      }
      if [[ "$a" != "$b" ]]; then
        log_fail "$src" "STREAMINFO MD5 mismatch" "here=$a against=$b"
        return 1
      fi
      ;;
    peak)
      pa=$(float_abs_peak "$src") || {
        log_fail "$src" "peak measure failed"
        return 1
      }
      pb=$(float_abs_peak "$other") || {
        log_fail "$src" "against peak measure failed" "against=$other"
        return 1
      }
      delta=$(awk -v a="$pa" -v b="$pb" 'BEGIN {
        d = a - b; if (d < 0) d = -d; printf "%.10f\n", d
      }')
      if awk -v d="$delta" -v e="${COMPARE_PEAK_EPS}" 'BEGIN { exit (d > e) ? 0 : 1 }'; then
        log_fail "$src" "peak delta exceeds eps" \
          "here=$pa against=$pb delta=$delta eps=${COMPARE_PEAK_EPS}"
        return 1
      fi
      ;;
  esac

  log_progress "match (${COMPARE_MODE}): $src"
  log_success "$src" "match" "$(audio_md5 "$src" 2>/dev/null || true)" \
    "$(file_sha256 "$src")" "against-ok"
}
