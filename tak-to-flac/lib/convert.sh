#!/usr/bin/env bash
# TAK → FLAC (ffmpeg decode preferred; Takc fallback)

_tak_decode_to_wav() {
  local src="$1" tmpdir="$2" wav="$3"
  local err
  err="${tmpdir}/tak-decode.err"
  # Prefer ffmpeg when it knows TAK
  if ffmpeg -v error -y -i "$src" -map 0:a:0 -c:a pcm_s24le "$wav" 2>"$err"; then
    return 0
  fi
  if takc_resolve 2>/dev/null; then
    if takc_decode "$src" "$wav"; then
      return 0
    fi
  fi
  set_last_err_file "$err"
  log_err "FAILED TAK decode (ffmpeg + takc): $src"
  [[ -s "$err" ]] && { log_err "  stderr:"; sed 's/^/  | /' "$err" >&2; }
  return 1
}

convert_one() {
  local src="$1"
  local flac="${src%.*}.flac"
  local dest_dir tmpdir flac_tagged wav
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
  wav="${tmpdir}/decoded.wav"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $src"
  if ! _tak_decode_to_wav "$src" "$tmpdir" "$wav"; then
    log_fail "$src" "TAK decode failed"
    cleanup
    return 1
  fi

  if ! encode_flac_verified "$wav" "$tmpdir" "$src" >"${tmpdir}/enc.out"; then
    log_fail "$src" "encode/verify failed"
    cleanup
    return 1
  fi
  mapfile -t enc_out <"${tmpdir}/enc.out"
  md5_flac=${enc_out[2]}
  hash1=${enc_out[3]}

  # Tags from source when ffmpeg can read them; else copy untagged
  if ! tag_flac_from_source "$src" "${enc_out[0]}" "$flac_tagged" 2>/dev/null; then
    cp -f -- "${enc_out[0]}" "$flac_tagged"
  fi

  mv -f -- "$flac_tagged" "$flac"
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    rm -f -- "$src"
    notes="${notes};deleted-tak"
  fi
  log_info "verified: $flac  audio_md5=$md5_flac sha=$hash1"
  log_success "$src" "$flac" "$md5_flac" "$(file_sha256 "$flac")" "$notes"
  cleanup
}
