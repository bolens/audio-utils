#!/usr/bin/env bash
convert_one() {
  local flac="$1"
  local wv="${flac%.*}.wv"
  local dest_dir tmpdir out md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$wv" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if is_wavpack_pure "$wv" && sibling_matches_source "$flac" "$wv"; then
      log_progress "skip (wv ok): $wv"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$wv" "$(audio_md5 "$wv")" "$(file_sha256 "$wv")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $wv"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$wv")
  tmpdir=$(make_workdir "$dest_dir")
  out="${tmpdir}/out.wv"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac"
  if ! encode_lossless_ffmpeg "$flac" "$out" wavpack; then
    log_fail "$flac" "wavpack encode/verify failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  if ! is_wavpack_pure "$out"; then
    log_fail "$flac" "encoded wv not pure lossless" "out=$out"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$wv"
  md5=$(audio_md5 "$wv")
  sha=$(file_sha256 "$wv")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $wv  audio_md5=$md5"
  log_success "$flac" "$wv" "$md5" "$sha" "$notes"
  cleanup
}
