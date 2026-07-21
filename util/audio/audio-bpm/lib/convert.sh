#!/usr/bin/env bash
# Detect tempo for one audio file and write the BPM tag.
# FLAC via metaflac; other formats remux with ffmpeg -c copy.

# Detect tempo; prints integer BPM. Empty output = detection failed.
_abpm_detect() {
  local src=$1 raw=""
  case "${BPM_BACKEND:-}" in
    bpm)
      raw=$(ffmpeg -v error -i "$src" -vn -ac 1 -ar 44100 -f f32le - 2>/dev/null \
        | bpm 2>/dev/null) || raw=""
      ;;
    aubio)
      # aubio tempo prints beat timestamps (seconds); derive BPM from spacing.
      raw=$(aubio tempo "$src" 2>/dev/null \
        | awk 'NF { t[++n] = $1 } END {
            if (n >= 2 && t[n] > t[1]) printf "%.3f\n", 60.0 * (n - 1) / (t[n] - t[1])
          }') || raw=""
      ;;
  esac
  awk -v b="${raw:-}" 'BEGIN {
    v = b + 0
    if (b != "" && v >= 20 && v <= 500) printf "%d\n", int(v + 0.5)
  }'
}

# Existing BPM tag value (also checks MP3 TBPM).
_abpm_current() {
  local v
  v=$(audio_meta_get "$1" BPM)
  [[ -n "$v" ]] || v=$(audio_meta_get "$1" TBPM)
  printf '%s' "$v"
}

convert_one() {
  local src="$1" dir tmp tagged ext bpm

  if [[ "${OVERWRITE:-0}" -eq 0 && -n "$(_abpm_current "$src")" ]]; then
    log_progress "skip (bpm exists): $src"
    log_success "$src" "unchanged" "" "$(file_sha256 "$src")" "skipped-existing"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would tag-bpm: $src"
    return 0
  fi

  bpm=$(_abpm_detect "$src")
  if [[ -z "$bpm" ]]; then
    log_fail "$src" "BPM detection failed" "backend=${BPM_BACKEND:-}"
    return 1
  fi

  if [[ "${src,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    metaflac --remove-tag=BPM --set-tag="BPM=${bpm}" -- "$src"
    log_progress "tagged: $src (bpm=${bpm})"
    log_success "$src" "flac" "" "$(file_sha256 "$src")" "bpm=${bpm}"
    return 0
  fi

  ext=${src##*.}
  local -a meta=( )
  if [[ "${ext,,}" == mp3 ]]; then
    meta+=(-metadata "TBPM=${bpm}")
  else
    meta+=(-metadata "BPM=${bpm}")
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
  log_progress "tagged: $src (bpm=${bpm})"
  log_success "$src" "remux" "" "$(file_sha256 "$src")" "bpm=${bpm}"
}
