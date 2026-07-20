#!/usr/bin/env bash
# Per-file FLAC → MP3 convert + verify.

convert_one() {
  local flac="$1"
  local mp3="${flac%.*}.mp3"
  local dest_dir tmpdir out md5 sha notes="" d1 d2
  local force_reconvert=0
  local quality="${MP3_QUALITY_NAME:-v0}"

  if [[ -f "$mp3" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if mp3_ok "$mp3"; then
      log_progress "skip (mp3 ok): $mp3"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$mp3" "$(audio_md5 "$flac")" "$(file_sha256 "$mp3")" "$quality" "skipped-existing-ok"
      fi
      return 0
    fi
    log_info "note: existing mp3 failed probe; reconverting: $mp3"
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $mp3"
    log_info "would encode:         libmp3lame quality=$quality (${MP3_FF_ARGS[*]})"
    log_info "would verify:         duration ±50ms + audio stream"
    if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
      log_info "would delete:         $flac"
    fi
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    local terr
    terr=$(mktemp)
    flac -t "$flac" >"$terr" 2>&1 || true
    set_last_err_file "$terr"
    rm -f -- "$terr"
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  local ch rate
  ch=$(audio_channels "$flac" || true)
  rate=$(audio_sample_rate "$flac" || true)
  if [[ -z "$ch" ]] || ((ch > 2)); then
    log_fail "$flac" "unsupported channel count for MP3" "channels=${ch:-unknown} (max 2)"
    return 1
  fi
  case "$rate" in
    8000|11025|12000|16000|22050|24000|32000|44100|48000) ;;
    *)
      log_fail "$flac" "unsupported sample rate for MP3" "rate=${rate:-unknown} (no silent resample)"
      return 1
      ;;
  esac

  dest_dir=$(dirname -- "$mp3")
  tmpdir=$(make_workdir "$dest_dir")
  out="${tmpdir}/out.mp3"

  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || chmod -R u+w -- "$tmpdir" 2>/dev/null
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $flac (quality=$quality)"

  if ! encode_mp3 "$flac" "$out"; then
    log_fail "$flac" "encode mp3 failed" "quality=$quality tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  if ! mp3_ok "$out"; then
    log_fail "$flac" "mp3 probe failed after encode" "out=$out"
    cleanup
    return 1
  fi

  if ! durations_match "$flac" "$out" 0.05; then
    d1=$(audio_duration_sec "$flac" || echo "?")
    d2=$(audio_duration_sec "$out" || echo "?")
    log_fail "$flac" "duration mismatch (>50ms)" "flac=${d1}s mp3=${d2}s"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$mp3"
  md5=$(audio_md5 "$flac")
  sha=$(file_sha256 "$mp3")

  log_info "verified: $mp3"
  log_info "  mp3_sha256=$sha  src_audio_md5=$md5  quality=$quality"
  log_info "  duration=$(audio_duration_sec "$mp3")s"

  notes="converted"
  ((force_reconvert)) && notes="reconverted-corrupt-mp3"

  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    log_info "deleted: $flac"
    notes="${notes};deleted-flac"
  fi

  log_success "$flac" "$mp3" "$md5" "$sha" "$quality" "$notes"
  cleanup
}
