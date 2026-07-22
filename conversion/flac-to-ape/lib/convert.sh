#!/usr/bin/env bash
# FLAC → APE via mac (Monkey's Audio); verify by ffmpeg decode MD5.

convert_one() {
  local flac="$1"
  local ape="${flac%.*}.ape"
  local dest_dir tmpdir wav out verify_wav
  local md5_src md5_dec sha bits pcm notes=""
  local force_reconvert=0
  local level="${APE_LEVEL:-normal}"

  if [[ -f "$ape" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if sibling_matches_source "$flac" "$ape"; then
      log_progress "skip (ape ok): $ape"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$ape" "$(audio_md5 "$ape")" "$(file_sha256 "$ape")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $ape (level=$level)"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$ape")
  tmpdir=$(make_workdir "$dest_dir")
  wav="${tmpdir}/pcm.wav"
  out="${tmpdir}/out.ape"
  verify_wav="${tmpdir}/verify.wav"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac (level=$level)"

  # Remux FLAC → WAV at the source bit depth (mac takes 8/16/24-bit WAV).
  bits=$(audio_bits_per_sample "$flac")
  pcm=pcm_s16le
  [[ -n "$bits" && "$bits" -gt 16 ]] && pcm=pcm_s24le
  if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$pcm" "$wav" 2>"${tmpdir}/wav.err"; then
    set_last_err_file "${tmpdir}/wav.err"
    log_fail "$flac" "flac->wav remux failed"
    cleanup
    return 1
  fi

  if ((${#MAC_CMD[@]} == 0)); then
    mac_resolve || { log_fail "$flac" "mac not available"; cleanup; return 1; }
  fi

  if ! mac_encode "$wav" "$out" "$level"; then
    log_fail "$flac" "mac encode failed" "level=$level"
    cleanup
    return 1
  fi

  # Verify: decode the APE with ffmpeg back to the same PCM format.
  if ! ffmpeg -v error -y -i "$out" -map 0:a:0 -c:a "$pcm" "$verify_wav" 2>"${tmpdir}/dec.err"; then
    set_last_err_file "${tmpdir}/dec.err"
    log_fail "$flac" "ape decode verify failed"
    cleanup
    return 1
  fi

  md5_src=$(audio_md5 "$flac")
  md5_dec=$(audio_md5 "$verify_wav")
  if [[ -z "$md5_src" || -z "$md5_dec" || "$md5_src" != "$md5_dec" ]]; then
    log_fail "$flac" "APE verify MD5 mismatch" "flac=$md5_src decoded=$md5_dec"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$ape"
  sha=$(file_sha256 "$ape")
  notes="converted;level=$level"
  ((force_reconvert)) && notes="reconverted;level=$level"
  # mac writes no tags; surface the loss instead of hiding it (see README).
  if flac_tag_export "$flac" | grep -q .; then
    notes="${notes};tags=dropped"
    log_note "note: APE output carries no tags (mac limitation): $ape"
  fi
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $ape  audio_md5=$md5_src"
  log_success "$flac" "$ape" "$md5_src" "$sha" "$notes"
  cleanup
}
