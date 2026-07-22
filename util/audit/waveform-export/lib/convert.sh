#!/usr/bin/env bash
# Render one waveform PNG via ffmpeg showwavespic.

convert_one() {
  local src="$1" out err

  # Full source name kept (song.mp3 → song.mp3.waveform.png) so files
  # differing only by extension cannot collide.
  out="${src}.waveform.png"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would waveform: $src -> $(basename -- "$out")"
    return 0
  fi

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (exists): $out"
    log_success "$src" "$out" "" "" "exists"
    return 0
  fi

  err=$(audio_utils_mktemp "waveerr.XXXXXX") || {
    log_fail "$src" "cannot create temp file"
    return 1
  }

  if ! ffmpeg -v error -y -i "$src" \
    -lavfi "showwavespic=s=${WAVEFORM_SIZE}:colors=${WAVEFORM_COLORS}" \
    -frames:v 1 "$out" 2>"$err"; then
    set_last_err_file "$err"
    rm -f -- "$err" "$out"
    log_fail "$src" "waveform render failed"
    return 1
  fi

  if [[ ! -s "$out" ]]; then
    rm -f -- "$err" "$out"
    log_fail "$src" "waveform render produced empty file"
    return 1
  fi
  rm -f -- "$err"

  log_progress "rendered: $out"
  log_success "$src" "$out" "" "$(file_sha256 "$out")" "png"
}
