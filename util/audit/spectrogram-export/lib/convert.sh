#!/usr/bin/env bash
# Render one spectrogram PNG: sox for PCM-ish inputs, ffmpeg for the rest.

_spec_sox() {
  local src=$1 out=$2 err=$3
  sox "$src" -n spectrogram -o "$out" 2>"$err"
}

_spec_ffmpeg() {
  local src=$1 out=$2 err=$3
  ffmpeg -v error -y -i "$src" \
    -lavfi "showspectrumpic=s=${SPECTROGRAM_SIZE}:legend=1" \
    -frames:v 1 "$out" 2>"$err"
}

convert_one() {
  local src="$1" out err rc=1

  # Full source name kept (song.mp3 → song.mp3.spectrogram.png) so files
  # differing only by extension cannot collide.
  out="${src}.spectrogram.png"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would spectrogram: $src → $(basename -- "$out")"
    return 0
  fi

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_progress "skip (exists): $out"
    log_success "$src" "$out" "" "" "exists"
    return 0
  fi

  err=$(audio_utils_mktemp "specerr.XXXXXX") || {
    log_fail "$src" "cannot create temp file"
    return 1
  }

  case "${src,,}" in
    *.flac | *.wav | *.aiff | *.aif)
      if command -v sox >/dev/null 2>&1; then
        _spec_sox "$src" "$out" "$err" && rc=0
      fi
      if ((rc != 0)); then
        _spec_ffmpeg "$src" "$out" "$err" && rc=0
      fi
      ;;
    *)
      _spec_ffmpeg "$src" "$out" "$err" && rc=0
      ;;
  esac

  if ((rc != 0)) || [[ ! -s "$out" ]]; then
    set_last_err_file "$err"
    rm -f -- "$err" "$out"
    log_fail "$src" "spectrogram render failed"
    return 1
  fi
  rm -f -- "$err"

  log_progress "rendered: $out"
  log_success "$src" "$out" "" "$(file_sha256 "$out")" "png"
}
