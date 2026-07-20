#!/usr/bin/env bash
# Per-file FLAC → AIFF convert + verify.

convert_one() {
  local flac="$1"
  local aiff="${flac%.*}.aiff"
  local dest_dir tmpdir target tagged src md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$aiff" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if pcm_ok "$aiff" && sibling_matches_source "$flac" "$aiff"; then
      log_progress "skip (aiff ok): $aiff"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$aiff" "$(audio_md5 "$aiff")" "$(file_sha256 "$aiff")" "skipped-existing-ok"
      fi
      return 0
    fi
    log_info "note: existing aiff failed probe/MD5; reconverting: $aiff"
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    target=$(target_pcm_be_codec "$flac" || echo pcm_s24be)
    log_progress "would convert+verify: $flac -> $aiff"
    log_info "would decode:         flac → $target (dual + audio MD5)"
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

  dest_dir=$(dirname -- "$aiff")
  tmpdir=$(make_workdir "$dest_dir")
  tagged="${tmpdir}/tagged.aiff"

  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || chmod -R u+w -- "$tmpdir" 2>/dev/null
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $flac"
  target=$(target_pcm_be_codec "$flac")

  if ! decode_flac_verified "$flac" "$tmpdir" "$target" aiff >"${tmpdir}/decode.path"; then
    log_fail "$flac" "decode/verify failed" "codec=$target tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  src=$(tail -n1 "${tmpdir}/decode.path")
  if [[ ! -f "$src" ]]; then
    log_fail "$flac" "decode/verify failed (missing aiff)" "got=${src:-empty}"
    cleanup
    return 1
  fi

  if ! tag_pcm_from_flac "$flac" "$src" "$tagged"; then
    log_fail "$flac" "tag/cover copy failed" "aiff_in=$src"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$aiff"
  md5=$(audio_md5 "$aiff")
  sha=$(file_sha256 "$aiff")

  log_info "verified: $aiff"
  log_info "  aiff_sha256=$sha  audio_md5=$md5  pcm=$target"

  notes="converted;$target"
  ((force_reconvert)) && notes="reconverted-corrupt-aiff;$target"

  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    log_info "deleted: $flac"
    notes="${notes};deleted-flac"
  fi

  log_success "$flac" "$aiff" "$md5" "$sha" "$notes"
  cleanup
}
