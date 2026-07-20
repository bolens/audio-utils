#!/usr/bin/env bash
# Per-file FLAC → WAV convert + verify.

convert_one() {
  local flac="$1"
  local wav="${flac%.*}.wav"
  local dest_dir tmpdir target tagged src md5 sha notes=""
  local force_reconvert=0

  # Smart skip
  if [[ -f "$wav" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if wav_ok "$wav"; then
      log_progress "skip (wav ok): $wav"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$wav" "$(audio_md5 "$wav")" "$(file_sha256 "$wav")" "skipped-existing-ok"
      fi
      return 0
    fi
    log_info "note: existing wav failed probe; reconverting: $wav"
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    target=$(target_wav_codec "$flac" || echo pcm_s24le)
    log_progress "would convert+verify: $flac -> $wav"
    log_info "would decode:         flac → $target (dual + audio MD5)"
    log_info "would tag:            copy metadata/cover from FLAC → WAV"
    if [[ "${DELETE_FLAC:-0}" -eq 1 ]]; then
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

  dest_dir=$(dirname -- "$wav")
  tmpdir=$(make_workdir "$dest_dir")
  tagged="${tmpdir}/tagged.wav"

  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || chmod -R u+w -- "$tmpdir" 2>/dev/null
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $flac"
  target=$(target_wav_codec "$flac")

  if ! decode_flac_verified "$flac" "$tmpdir" "$target" >"${tmpdir}/decode.path"; then
    log_fail "$flac" "decode/verify failed" "codec=$target tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  src=$(tail -n1 "${tmpdir}/decode.path")
  if [[ ! -f "$src" ]]; then
    log_fail "$flac" "decode/verify failed (missing wav)" "got=${src:-empty}"
    cleanup
    return 1
  fi

  if ! tag_wav "$flac" "$src" "$tagged"; then
    log_fail "$flac" "tag/cover copy failed" "wav_in=$src"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$wav"
  md5=$(audio_md5 "$wav")
  sha=$(file_sha256 "$wav")

  log_info "verified: $wav"
  log_info "  wav_sha256=$sha  audio_md5=$md5  pcm=$target"

  notes="converted;$target"
  ((force_reconvert)) && notes="reconverted-corrupt-wav;$target"

  if [[ "${DELETE_FLAC:-0}" -eq 1 ]]; then
    rm -f -- "$flac"
    log_info "deleted: $flac"
    notes="${notes};deleted-flac"
  fi

  log_success "$flac" "$wav" "$md5" "$sha" "$notes"
  cleanup
}
