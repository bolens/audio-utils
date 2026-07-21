#!/usr/bin/env bash
# Detect musical key for one audio file and write the INITIALKEY tag.
# FLAC via metaflac; other formats remux with ffmpeg -c copy.

# Detect key; prints e.g. "Am" / "F#" (or "8A" with -C). Empty = failed.
_akey_detect() {
  local key
  if [[ "${KEY_NOTATION:-standard}" == camelot ]]; then
    key=$(keyfinder-cli -n camelot "$1" 2>/dev/null) || key=""
  else
    key=$(keyfinder-cli "$1" 2>/dev/null) || key=""
  fi
  key=$(flac_tag_trim "$key")
  case "${key^^}" in
    "" | SILENCE) return 0 ;;
  esac
  printf '%s\n' "$key"
}

# Existing key tag value (also checks MP3 TKEY and initial_key).
_akey_current() {
  local v
  v=$(audio_meta_get "$1" INITIALKEY)
  [[ -n "$v" ]] || v=$(audio_meta_get "$1" TKEY)
  [[ -n "$v" ]] || v=$(audio_meta_get "$1" initial_key)
  printf '%s' "$v"
}

convert_one() {
  local src="$1" dir tmp tagged ext key

  if [[ "${OVERWRITE:-0}" -eq 0 && -n "$(_akey_current "$src")" ]]; then
    log_progress "skip (key exists): $src"
    log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "skipped-existing"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would tag-key: $src"
    return 0
  fi

  key=$(_akey_detect "$src")
  if [[ -z "$key" ]]; then
    log_fail "$src" "key detection failed" "backend=keyfinder-cli"
    return 1
  fi

  if [[ "${src,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    metaflac --remove-tag=INITIALKEY --set-tag="INITIALKEY=${key}" -- "$src"
    log_progress "tagged: $src (key=${key})"
    log_success "$src" "flac" "" "$(file_sha256 "$src")" "key=${key}"
    return 0
  fi

  ext=${src##*.}
  local -a meta=( )
  if [[ "${ext,,}" == mp3 ]]; then
    meta+=(-metadata "TKEY=${key}")
  else
    meta+=(-metadata "INITIALKEY=${key}")
  fi

  dir=$(dirname -- "$src")
  tmp=$(make_workdir "$dir")
  tagged="${tmp}/tagged.${ext}"
  if ! audio_meta_remux_tags "$src" "$tagged" "${meta[@]}"; then
    log_fail "$src" "tag remux failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  if ! mv -f -- "$tagged" "$src"; then
    log_fail "$src" "replace failed"
    unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
    return 1
  fi
  unregister_tmpdir "$tmp"; rm -rf -- "$tmp"
  log_progress "tagged: $src (key=${key})"
  log_success "$src" "remux" "" "$(file_sha256 "$src")" "key=${key}"
}
