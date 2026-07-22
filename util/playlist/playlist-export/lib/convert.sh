#!/usr/bin/env bash
# Export one playlist: copy entries into DEST/<stem>/ and write a fresh .m3u.

# Pick a destination filename; uniquify on collision with a different size.
_plexp_target() {
  local destdir=$1 base=$2 srcsize=$3
  local target="${destdir}/${base}" stem ext n=2
  if [[ ! -e "$target" || "${OVERWRITE:-0}" -eq 1 ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  if [[ "$(file_bytes "$target")" == "$srcsize" ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  stem=${base%.*}
  ext=${base##*.}
  while [[ -e "${destdir}/${stem} (${n}).${ext}" ]]; do
    if [[ "$(file_bytes "${destdir}/${stem} (${n}).${ext}")" == "$srcsize" ]]; then
      break
    fi
    ((n++))
  done
  printf '%s\n' "${destdir}/${stem} (${n}).${ext}"
}

convert_one() {
  local pl="$1" stem destdir out line path title dur base target size
  local copied=0 skipped=0 missing=0 idx=0
  local -a entries=()
  local tsv

  stem=$(basename -- "$pl")
  stem=${stem%.*}
  destdir="${EXPORT_DEST:?}/${stem}"
  out="${destdir}/${stem}.m3u"

  mapfile -t entries < <(playlist_parse "$pl") || entries=()
  if ((${#entries[@]} == 0)); then
    log_fail "$pl" "playlist empty or unparseable"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would export: $pl (${#entries[@]} entries) -> $destdir"
    return 0
  fi

  mkdir -p -- "$destdir" || {
    log_fail "$pl" "cannot create destination" "$destdir"
    return 1
  }

  tsv=$(audio_utils_mktemp "plexp.XXXXXX") || {
    log_fail "$pl" "cannot create temp file"
    return 1
  }

  for line in "${entries[@]}"; do
    path=${line%%$'\x1f'*}
    title=${line#*$'\x1f'}
    dur=${title#*$'\x1f'}
    title=${title%%$'\x1f'*}

    if [[ ! -f "$path" ]]; then
      ((missing++)) || true
      log_info "  missing: $path"
      continue
    fi

    ((idx++)) || true
    base=$(basename -- "$path")
    if [[ "${EXPORT_NUMBER:-0}" -eq 1 ]]; then
      base=$(printf '%03d - %s' "$idx" "$base")
    fi
    size=$(file_bytes "$path")
    target=$(_plexp_target "$destdir" "$base" "$size")

    if [[ -e "$target" && "${OVERWRITE:-0}" -eq 0 && "$(file_bytes "$target")" == "$size" ]]; then
      ((skipped++)) || true
    else
      if ! cp -p -- "$path" "$target"; then
        rm -f -- "$tsv"
        log_fail "$pl" "copy failed" "src=$path dest=$target"
        return 1
      fi
      ((copied++)) || true
    fi
    printf '%s\x1f%s\x1f%s\n' "$target" "$title" "$dur" >>"$tsv"
  done

  if [[ ! -s "$tsv" ]]; then
    rm -f -- "$tsv"
    log_fail "$pl" "no playlist entries could be exported" "missing=$missing"
    return 1
  fi

  if ! playlist_write m3u "$out" "$destdir" relative <"$tsv"; then
    rm -f -- "$tsv"
    log_fail "$pl" "cannot write destination playlist" "$out"
    return 1
  fi
  rm -f -- "$tsv"

  if ((missing > 0)); then
    log_fail "$pl" "exported with missing entries" \
      "copied=$copied skipped=$skipped missing=$missing"
    return 1
  fi

  log_progress "exported: $pl -> $destdir (copied=$copied skipped=$skipped)"
  log_success "$pl" "exported" "" "$(file_sha256 "$out")" \
    "copied=${copied};skipped=${skipped}"
}
