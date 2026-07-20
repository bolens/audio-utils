#!/usr/bin/env bash
# Per-file convert + verify pipeline (and retag-only mode).

flac_ok() {
  local flac="$1"
  [[ -f "$flac" && -s "$flac" ]] || return 1
  flac -t --silent "$flac" 2>/dev/null
}

# Re-apply tags/cover from WAV onto an existing valid FLAC (no re-encode).
retag_one() {
  local wav="$1"
  local flac="${wav%.*}.flac"
  local dest_dir tmpdir tagged md5 sha

  if [[ ! -f "$flac" ]]; then
    log_fail "$wav" "retag-only: no sibling flac" "expected=$flac"
    return 1
  fi
  if ! flac_ok "$flac"; then
    log_fail "$wav" "retag-only: flac missing/corrupt (run full convert)" "flac=$flac"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would retag: $flac (from $wav)"
    return 0
  fi

  log_progress "retag: $flac"
  dest_dir=$(dirname -- "$flac")
  tmpdir=$(make_workdir "$dest_dir")
  tagged="${tmpdir}/tagged.flac"

  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || chmod -R u+w -- "$tmpdir" 2>/dev/null
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  if ! tag_flac "$wav" "$flac" "$tagged"; then
    log_fail "$wav" "retag/cover copy failed" "flac=$flac tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$flac"
  md5=$(audio_md5 "$flac")
  sha=$(file_sha256 "$flac")
  log_info "retagged: $flac"
  log_info "  flac_sha256=$sha  audio_md5=$md5"
  log_success "$wav" "$flac" "$md5" "$sha" "retag-only"
  cleanup
}

convert_one() {
  local wav="$1"
  local flac="${wav%.*}.flac"
  local dest_dir tmpdir flac1 flac2 flac3 flac_tagged decoded clean_tmp src
  local hash1 hash2 hash3 md5_flac md5_decoded md5_src codec notes=""
  local force_reconvert=0 decode_err

  if [[ "${RETAG_ONLY:-0}" -eq 1 ]]; then
    retag_one "$wav"
    return $?
  fi

  # Smart skip: existing FLAC that passes flac -t
  if [[ -f "$flac" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if flac_ok "$flac"; then
      log_progress "skip (flac ok): $flac"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$wav" "$flac" "$(audio_md5 "$flac")" "$(file_sha256 "$flac")" "skipped-existing-ok"
      fi
      return 0
    fi
    log_info "note: existing flac failed flac -t; reconverting: $flac"
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    codec=$(audio_codec "$wav" || true)
    log_progress "would convert+verify: $wav -> $flac"
    log_info "would remux:          ${codec:-unknown} → clean PCM temp (dual + e2e MD5)"
    log_info "would tag:            copy metadata/cover from WAV → FLAC"
    log_info "would workdir:        next to destination (atomic mv)"
    if [[ "${DELETE_WAV:-0}" -eq 1 ]]; then
      log_info "would delete:         $wav"
    elif [[ "${CLEAN_WAV:-0}" -eq 1 ]]; then
      log_info "would clean:          $wav (replace with FLAC decode)"
    fi
    return 0
  fi

  dest_dir=$(dirname -- "$flac")
  tmpdir=$(make_workdir "$dest_dir")
  flac1="${tmpdir}/pass1.flac"
  flac2="${tmpdir}/pass2.flac"
  flac3="${tmpdir}/roundtrip.flac"
  flac_tagged="${tmpdir}/tagged.flac"
  decoded="${tmpdir}/decoded.wav"
  decode_err="${tmpdir}/decode.err"

  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || chmod -R u+w -- "$tmpdir" 2>/dev/null
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $wav"

  # Prep prints path on stdout; run in-process (not $()) so LAST_ERR survives.
  if ! prepare_source "$wav" "$tmpdir" >"${tmpdir}/prep.path"; then
    log_fail "$wav" "prepare/remux failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  src=$(tail -n1 "${tmpdir}/prep.path")
  if [[ ! -f "$src" ]]; then
    log_fail "$wav" "prepare/remux failed (missing prep file)" "got=${src:-empty} tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  if ! encode_flac "$src" "$flac1"; then
    log_fail "$wav" "encode pass1 failed" "src=$src dest=$flac1"
    cleanup
    return 1
  fi
  if ! encode_flac "$src" "$flac2"; then
    log_fail "$wav" "encode pass2 failed" "src=$src dest=$flac2"
    cleanup
    return 1
  fi

  hash1=$(file_sha256 "$flac1")
  hash2=$(file_sha256 "$flac2")
  if [[ "$hash1" != "$hash2" ]]; then
    log_fail "$wav" "dual-encode SHA-256 mismatch" "pass1=$hash1 pass2=$hash2"
    cleanup
    return 1
  fi

  if ! flac -d --silent -o "$decoded" "$flac1" 2>"$decode_err"; then
    set_last_err_file "$decode_err"
    log_fail "$wav" "decode for verify failed" "flac=$flac1 decoded=$decoded"
    cleanup
    return 1
  fi
  if ! encode_flac "$decoded" "$flac3"; then
    log_fail "$wav" "re-encode for verify failed" "decoded=$decoded dest=$flac3"
    cleanup
    return 1
  fi

  hash3=$(file_sha256 "$flac3")
  if [[ "$hash1" != "$hash3" ]]; then
    log_fail "$wav" "round-trip SHA-256 mismatch" "encode=$hash1 roundtrip=$hash3"
    cleanup
    return 1
  fi

  md5_flac=$(audio_md5 "$flac1")
  md5_decoded=$(audio_md5 "$decoded")
  if [[ -z "$md5_flac" || -z "$md5_decoded" || "$md5_flac" != "$md5_decoded" ]]; then
    log_fail "$wav" "audio MD5 mismatch after decode" "flac_md5=$md5_flac decoded_md5=$md5_decoded"
    cleanup
    return 1
  fi

  md5_src=$(audio_md5 "$src")
  if [[ -z "$md5_src" || "$md5_src" != "$md5_flac" ]]; then
    log_fail "$wav" "end-to-end prep→FLAC audio MD5 mismatch" "prep_md5=$md5_src flac_md5=$md5_flac"
    cleanup
    return 1
  fi
  log_verbose "verified e2e: prep audio MD5 == FLAC audio MD5 ($md5_flac)"

  if ! flac -t --silent "$flac1" 2>"$decode_err"; then
    set_last_err_file "$decode_err"
    log_fail "$wav" "flac -t failed" "flac=$flac1"
    cleanup
    return 1
  fi

  if ! tag_flac "$wav" "$flac1" "$flac_tagged"; then
    log_fail "$wav" "tag/cover copy failed" "wav=$wav flac_in=$flac1 out=$flac_tagged"
    cleanup
    return 1
  fi

  mv -f -- "$flac_tagged" "$flac"

  log_info "verified: $flac"
  log_info "  flac_sha256=$(file_sha256 "$flac")"
  log_info "  audio_md5=$md5_flac"
  log_info "  codec=$(audio_codec "$wav" || echo '?')  size=$(human_bytes "$(file_bytes "$wav")")"

  notes="converted"
  ((force_reconvert)) && notes="reconverted-corrupt-flac"

  if [[ "${DELETE_WAV:-0}" -eq 1 ]]; then
    rm -f -- "$wav"
    log_info "deleted: $wav"
    notes="${notes};deleted-wav"
  elif [[ "${CLEAN_WAV:-0}" -eq 1 ]]; then
    clean_tmp="$(dirname -- "$wav")/.$(basename -- "$wav").clean.$$"
    if ! cp -f -- "$decoded" "$clean_tmp"; then
      log_fail "$wav" "clean copy failed (flac kept)" "src=$decoded dest=$clean_tmp"
      rm -f -- "$clean_tmp"
      cleanup
      return 1
    fi
    if ! mv -f -- "$clean_tmp" "$wav"; then
      log_fail "$wav" "clean replace failed (flac kept)" "src=$clean_tmp dest=$wav"
      rm -f -- "$clean_tmp"
      cleanup
      return 1
    fi
    log_info "cleaned: $wav (integer PCM from FLAC; matches FLAC)"
    notes="${notes};cleaned-wav"
  fi

  log_success "$wav" "$flac" "$md5_flac" "$(file_sha256 "$flac")" "$notes"
  cleanup
}
