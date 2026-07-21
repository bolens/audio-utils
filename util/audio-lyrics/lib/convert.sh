#!/usr/bin/env bash
# Report / import / export lyrics for one file.

_ly_tag_value() {
  local f=$1 v
  v=$(audio_meta_get "$f" LYRICS)
  [[ -n "$v" ]] || v=$(audio_meta_get "$f" UNSYNCEDLYRICS)
  [[ -n "$v" ]] || v=$(audio_meta_get "$f" lyrics-eng)
  printf '%s' "$v"
}

# Print the first existing sidecar (.lrc preferred, then .txt); rc 1 if none.
_ly_sidecar() {
  local f=$1 stem
  stem=${f%.*}
  if [[ -f "${stem}.lrc" ]]; then
    printf '%s\n' "${stem}.lrc"
  elif [[ -f "${stem}.txt" ]]; then
    printf '%s\n' "${stem}.txt"
  else
    return 1
  fi
}

_ly_report() {
  local f=$1 tag sidecar
  tag=$(_ly_tag_value "$f")
  sidecar=$(_ly_sidecar "$f") || sidecar=""
  if [[ -z "$tag" && -z "$sidecar" ]]; then
    log_fail "$f" "no lyrics" "no LYRICS tag, no .lrc/.txt sidecar"
    return 1
  fi
  local how=()
  [[ -z "$tag" ]] || how+=("tag")
  [[ -z "$sidecar" ]] || how+=("sidecar")
  local IFS=+
  log_progress "ok: $f (${how[*]})"
  log_success "$f" "clean" "" "" "${how[*]}"
}

_ly_import() {
  local f=$1 sidecar tag
  if [[ "${f,,}" != *.flac ]]; then
    log_progress "skip (import is FLAC-only): $f"
    log_success "$f" "skip" "" "" "import-flac-only"
    return 0
  fi
  sidecar=$(_ly_sidecar "$f") || {
    log_fail "$f" "no lyrics sidecar to import" "looked=.lrc,.txt"
    return 1
  }
  tag=$(_ly_tag_value "$f")
  if [[ -n "$tag" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (tag exists): $f"
    log_success "$f" "skip" "" "" "tag-exists"
    return 0
  fi
  if ! metaflac --remove-tag=LYRICS \
    --set-tag-from-file="LYRICS=${sidecar}" -- "$f" 2>/dev/null; then
    log_fail "$f" "metaflac import failed" "sidecar=$sidecar"
    return 1
  fi
  log_progress "imported: $f ← $(basename -- "$sidecar")"
  log_success "$f" "imported" "" "$(file_sha256 "$f")" "from=$(basename -- "$sidecar")"
}

_ly_export() {
  local f=$1 tag out
  tag=$(_ly_tag_value "$f")
  if [[ -z "$tag" ]]; then
    log_fail "$f" "no LYRICS tag to export"
    return 1
  fi
  out="${f%.*}.lrc"
  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (exists): $out"
    log_success "$f" "skip" "" "" "sidecar-exists"
    return 0
  fi
  if ! printf '%s\n' "$tag" >"$out"; then
    log_fail "$f" "cannot write sidecar" "out=$out"
    return 1
  fi
  log_progress "exported: $out"
  log_success "$f" "exported" "" "$(file_sha256 "$out")" "to=$(basename -- "$out")"
}

convert_one() {
  local f="$1"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would lyrics-${LYRICS_MODE:-report}: $f"
    return 0
  fi

  case "${LYRICS_MODE:-report}" in
    import) _ly_import "$f" ;;
    export) _ly_export "$f" ;;
    *) _ly_report "$f" ;;
  esac
}
