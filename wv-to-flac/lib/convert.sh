#!/usr/bin/env bash
convert_one() {
  local src="$1"
  local flac="${src%.*}.flac"
  local dest_dir tmpdir flac_tagged prep
  local md5_flac hash1 notes=""
  local force_reconvert=0
  local -a enc_out

  if [[ -f "$flac" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if flac_ok "$flac" && sibling_matches_source "$src" "$flac"; then
      log_progress "skip (flac ok): $flac"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$src" "$flac" "$(audio_md5 "$flac")" "$(file_sha256 "$flac")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $src -> $flac"
    [[ "${DELETE_SOURCE:-0}" -eq 1 ]] && log_info "would delete: $src"
    return 0
  fi

  dest_dir=$(dirname -- "$flac")
  tmpdir=$(make_workdir "$dest_dir")
  flac_tagged="${tmpdir}/tagged.flac"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $src"
  if ! decode_to_pcm_prep "$src" "$tmpdir" >"${tmpdir}/prep.path"; then
    log_fail "$src" "decode to PCM failed"
    cleanup
    return 1
  fi
  prep=$(tail -n1 "${tmpdir}/prep.path")
  [[ -f "$prep" ]] || { log_fail "$src" "missing prep"; cleanup; return 1; }

  if ! encode_flac_verified "$prep" "$tmpdir" "$src" >"${tmpdir}/enc.out"; then
    log_fail "$src" "encode/verify failed"
    cleanup
    return 1
  fi
  mapfile -t enc_out <"${tmpdir}/enc.out"
  md5_flac=${enc_out[2]}
  hash1=${enc_out[3]}

  if ! tag_flac_from_source "$src" "${enc_out[0]}" "$flac_tagged"; then
    log_fail "$src" "tag/cover copy failed"
    cleanup
    return 1
  fi

  mv -f -- "$flac_tagged" "$flac"
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    rm -f -- "$src"
    notes="${notes};deleted-wv"
  fi
  log_info "verified: $flac  audio_md5=$md5_flac sha=$hash1"
  log_success "$src" "$flac" "$md5_flac" "$(file_sha256 "$flac")" "$notes"
  cleanup
}
