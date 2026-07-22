#!/usr/bin/env bash
# List, extract, or embed chapters on one .m4b / .m4a.

convert_one() {
  local src="$1"
  local n line idx start end title tmp dest sha
  local dest_dir

  case "${src,,}" in
    *.m4b|*.m4a) ;;
    *)
      log_progress "skip (not m4b/m4a): $src"
      log_success "$src" "skip" "" "" "unsupported"
      return 0
      ;;
  esac

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    n=$(chapters_count "$src" 2>/dev/null || echo 0)
    if [[ -n "${CHAPTERS_EXTRACT:-}" ]]; then
      log_progress "would extract chapters ($n) -> $CHAPTERS_EXTRACT: $src"
    elif [[ -n "${CHAPTERS_EMBED:-}" ]]; then
      log_progress "would embed chapters from $CHAPTERS_EMBED: $src"
    else
      log_progress "would list chapters ($n): $src"
    fi
    return 0
  fi

  if [[ -n "${CHAPTERS_EXTRACT:-}" ]]; then
    if ! chapters_extract "$src" "$CHAPTERS_EXTRACT"; then
      log_fail "$src" "no chapters to extract"
      return 1
    fi
    n=$(chapters_count "$src")
    log_progress "extracted $n chapters -> $CHAPTERS_EXTRACT"
    log_success "$src" "extracted" "" "$(file_sha256 "$src")" "chapters=$n"
    return 0
  fi

  if [[ -n "${CHAPTERS_EMBED:-}" ]]; then
    dest_dir=$(dirname -- "$src")
    tmp=$(make_workdir "$dest_dir")
    dest="${tmp}/with-chapters.${src##*.}"
    if ! chapters_embed "$src" "$dest" "$CHAPTERS_EMBED"; then
      unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
      log_fail "$src" "chapter embed failed"
      return 1
    fi
    if ! mv -f -- "$dest" "$src"; then
      unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
      log_fail "$src" "replace after embed failed"
      return 1
    fi
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    n=$(chapters_count "$src")
    sha=$(file_sha256 "$src")
    log_progress "embedded $n chapters: $src"
    log_success "$src" "embedded" "" "$sha" "chapters=$n"
    return 0
  fi

  # Default: list
  n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    IFS='|' read -r idx start end title <<<"$line"
    ((++n)) || true
    log_always "  [$idx] ${start}s -> ${end:-eof}s  ${title:-untitled}"
  done < <(chapters_list "$src" 2>/dev/null || true)

  if [[ "$n" -eq 0 ]]; then
    log_progress "no chapters: $src"
    log_success "$src" "none" "" "$(file_sha256 "$src")" "chapters=0"
    return 0
  fi

  log_progress "chapters=$n: $src"
  log_success "$src" "listed" "" "$(file_sha256 "$src")" "chapters=$n"
}
