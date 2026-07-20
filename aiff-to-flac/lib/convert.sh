#!/usr/bin/env bash
# Per-file AIFF → FLAC convert + verify (and retag-only).

retag_one() {
  local src="$1"
  local flac="${src%.*}.flac"
  local dest_dir tmpdir tagged md5 sha

  if [[ ! -f "$flac" ]]; then
    log_fail "$src" "retag-only: no sibling flac" "expected=$flac"
    return 1
  fi
  if ! flac_ok "$flac"; then
    log_fail "$src" "retag-only: flac missing/corrupt (run full convert)" "flac=$flac"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would retag: $flac (from $src)"
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

  if ! tag_flac_from_source "$src" "$flac" "$tagged"; then
    log_fail "$src" "retag/cover copy failed" "flac=$flac tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$flac"
  md5=$(audio_md5 "$flac")
  sha=$(file_sha256 "$flac")
  log_info "retagged: $flac"
  log_success "$src" "$flac" "$md5" "$sha" "retag-only"
  cleanup
}

convert_one() {
  local src="$1"
  local flac="${src%.*}.flac"
  local dest_dir tmpdir flac_tagged clean_tmp prep
  local md5_flac hash1 codec notes=""
  local force_reconvert=0
  local -a enc_out

  if [[ "${RETAG_ONLY:-0}" -eq 1 ]]; then
    retag_one "$src"
    return $?
  fi

  if [[ -f "$flac" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if flac_ok "$flac"; then
      log_progress "skip (flac ok): $flac"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$src" "$flac" "$(audio_md5 "$flac")" "$(file_sha256 "$flac")" "skipped-existing-ok"
      fi
      return 0
    fi
    log_info "note: existing flac failed flac -t; reconverting: $flac"
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    codec=$(audio_codec "$src" || true)
    log_progress "would convert+verify: $src -> $flac"
    log_info "would remux:          ${codec:-unknown} → clean PCM temp (dual + e2e MD5)"
    if [[ "${DELETE_SOURCE:-${DELETE_WAV:-0}}" -eq 1 ]]; then
      log_info "would delete:         $src"
    elif [[ "${CLEAN_WAV:-0}" -eq 1 ]]; then
      log_info "would clean:          $src (replace with FLAC decode)"
    fi
    return 0
  fi

  dest_dir=$(dirname -- "$flac")
  tmpdir=$(make_workdir "$dest_dir")
  flac_tagged="${tmpdir}/tagged.flac"

  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || chmod -R u+w -- "$tmpdir" 2>/dev/null
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $src"

  if ! prepare_source "$src" "$tmpdir" >"${tmpdir}/prep.path"; then
    log_fail "$src" "prepare/remux failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  prep=$(tail -n1 "${tmpdir}/prep.path")
  if [[ ! -f "$prep" ]]; then
    log_fail "$src" "prepare/remux failed (missing prep)" "got=${prep:-empty}"
    cleanup
    return 1
  fi

  if ! encode_flac_verified "$prep" "$tmpdir" "$src" >"${tmpdir}/enc.out"; then
    log_fail "$src" "encode/verify failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  mapfile -t enc_out <"${tmpdir}/enc.out"
  if ((${#enc_out[@]} < 4)); then
    log_fail "$src" "encode/verify failed (incomplete)" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  md5_flac=${enc_out[2]}
  hash1=${enc_out[3]}

  if ! tag_flac_from_source "$src" "${enc_out[0]}" "$flac_tagged"; then
    log_fail "$src" "tag/cover copy failed" "flac_in=${enc_out[0]}"
    cleanup
    return 1
  fi

  mv -f -- "$flac_tagged" "$flac"

  log_info "verified: $flac"
  log_info "  flac_sha256=$hash1  audio_md5=$md5_flac"

  notes="converted"
  ((force_reconvert)) && notes="reconverted-corrupt-flac"

  if [[ "${DELETE_SOURCE:-${DELETE_WAV:-0}}" -eq 1 ]]; then
    rm -f -- "$src"
    log_info "deleted: $src"
    notes="${notes};deleted-aiff"
  elif [[ "${CLEAN_WAV:-0}" -eq 1 ]]; then
    local target clean_err
    target=$(target_pcm_be_codec "$flac")
    clean_tmp="$(dirname -- "$src")/.$(basename -- "$src").clean.$$"
    clean_err="${tmpdir}/clean.err"
    if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$target" "$clean_tmp" 2>"$clean_err"; then
      log_fail "$src" "clean decode failed (flac kept)" "target=$target"
      rm -f -- "$clean_tmp"
      cleanup
      return 1
    fi
    if ! mv -f -- "$clean_tmp" "$src"; then
      log_fail "$src" "clean replace failed (flac kept)" "src=$clean_tmp"
      rm -f -- "$clean_tmp"
      cleanup
      return 1
    fi
    log_info "cleaned: $src (PCM from FLAC)"
    notes="${notes};cleaned-aiff"
  fi

  log_success "$src" "$flac" "$md5_flac" "$(file_sha256 "$flac")" "$notes"
  cleanup
}
