#!/usr/bin/env bash
# FLAC → TAK via Takc; verify by decode MD5.

convert_one() {
  local flac="$1"
  local tak="${flac%.*}.tak"
  local dest_dir tmpdir wav out verify_wav
  local md5_src md5_dec sha notes=""
  local force_reconvert=0
  local preset="${TAK_PRESET:-p2}"

  if [[ -f "$tak" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if sibling_matches_source "$flac" "$tak"; then
      log_progress "skip (tak ok): $tak"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$tak" "$(audio_md5 "$tak")" "$(file_sha256 "$tak")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $tak (preset=$preset)"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$tak")
  tmpdir=$(make_workdir "$dest_dir")
  wav="${tmpdir}/pcm.wav"
  out="${tmpdir}/out.tak"
  verify_wav="${tmpdir}/verify.wav"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac (preset=$preset)"

  # Remux FLAC → WAV for Takc
  if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a pcm_s24le "$wav" 2>"${tmpdir}/wav.err"; then
    set_last_err_file "${tmpdir}/wav.err"
    log_fail "$flac" "flac→wav remux failed"
    cleanup
    return 1
  fi

  if ((${#TAKC_CMD[@]} == 0)); then
    takc_resolve || { log_fail "$flac" "takc not available"; cleanup; return 1; }
  fi

  if ! takc_encode "$wav" "$out" "$preset"; then
    log_fail "$flac" "takc encode failed" "preset=$preset"
    cleanup
    return 1
  fi

  if ! takc_decode "$out" "$verify_wav"; then
    log_fail "$flac" "takc decode verify failed"
    cleanup
    return 1
  fi

  md5_src=$(audio_md5 "$flac")
  md5_dec=$(audio_md5 "$verify_wav")
  if [[ -z "$md5_src" || -z "$md5_dec" || "$md5_src" != "$md5_dec" ]]; then
    log_fail "$flac" "TAK verify MD5 mismatch" "flac=$md5_src decoded=$md5_dec"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$tak"
  sha=$(file_sha256 "$tak")
  notes="converted;preset=$preset"
  ((force_reconvert)) && notes="reconverted;preset=$preset"
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $tak  audio_md5=$md5_src"
  log_success "$flac" "$tak" "$md5_src" "$sha" "$notes"
  cleanup
}
