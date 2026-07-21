#!/usr/bin/env bash
# Normalize one playlist: format and/or path style; optional dedupe.

convert_one() {
  local pl="$1"
  local basedir fmt out_fmt out_ext out_path entries_file tmp_entries
  local notes="" dropped=0

  basedir=$(cd -- "$(dirname -- "$pl")" && pwd) || {
    log_fail "$pl" "cannot resolve directory"
    return 1
  }

  if ! fmt=$(playlist_detect_format "$pl"); then
    log_fail "$pl" "unknown playlist format"
    return 1
  fi

  if [[ -n "${PLAYLIST_OUT_FORMAT:-}" ]]; then
    out_fmt=$PLAYLIST_OUT_FORMAT
  else
    out_fmt=$fmt
  fi
  case "$out_fmt" in
    m3u8) out_fmt=m3u ;;
  esac
  out_ext=$(playlist_ext_for_format "$out_fmt") || {
    log_fail "$pl" "bad output format" "$out_fmt"
    return 1
  }

  # Stay in-place when output format family matches the file; else new sibling.
  if [[ -z "${PLAYLIST_OUT_FORMAT:-}" ]]; then
    out_path=$pl
  elif [[ "$out_fmt" == m3u && ( "${pl,,}" == *.m3u || "${pl,,}" == *.m3u8 ) ]]; then
    out_path=$pl
  elif [[ "$out_fmt" == pls && "${pl,,}" == *.pls ]]; then
    out_path=$pl
  elif [[ "$out_fmt" == xspf && "${pl,,}" == *.xspf ]]; then
    out_path=$pl
  else
    out_path="${pl%.*}.${out_ext}"
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would normalize: $pl → $out_path (${out_fmt}, ${PLAYLIST_PATH_MODE})"
    return 0
  fi

  if [[ "$out_path" != "$pl" && -f "$out_path" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (exists): $out_path"
    log_success "$pl" "skip" "" "$(file_sha256 "$pl")" "exists"
    return 0
  fi

  entries_file=$(audio_utils_mktemp "plentries.XXXXXX") || return 1
  playlist_parse "$pl" >"$entries_file" || {
    log_fail "$pl" "parse failed"
    return 1
  }

  if [[ "${PLAYLIST_DO_DEDUPE:-0}" -eq 1 ]]; then
    tmp_entries=$(audio_utils_mktemp "pldedupe.XXXXXX") || return 1
    PLAYLIST_DEDUPE_COUNT_FILE=$(audio_utils_mktemp "pldcount.XXXXXX")
    export PLAYLIST_DEDUPE_COUNT_FILE
    playlist_dedupe_entries "${PLAYLIST_DEDUPE_BY:-path}" <"$entries_file" >"$tmp_entries"
    dropped=$(cat "$PLAYLIST_DEDUPE_COUNT_FILE" 2>/dev/null || echo 0)
    unset PLAYLIST_DEDUPE_COUNT_FILE
    mv -f -- "$tmp_entries" "$entries_file"
    notes="dedupe_dropped=${dropped}"
  fi

  if ! playlist_write "$out_fmt" "$out_path" "$basedir" "${PLAYLIST_PATH_MODE:-relative}" <"$entries_file"; then
    log_fail "$pl" "write failed" "$out_path"
    return 1
  fi

  log_progress "normalized: $out_path"
  log_success "$pl" "normalized" "" "$(file_sha256 "$out_path")" "${notes:-ok}"
}
