#!/usr/bin/env bash
# FLAC → ALAC (.m4a)

convert_one() {
  local flac="$1"
  local m4a="${flac%.*}.m4a"
  local dest_dir tmpdir out md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$m4a" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if is_alac "$m4a" && sibling_matches_source "$flac" "$m4a"; then
      log_progress "skip (alac ok): $m4a"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$m4a" "$(audio_md5 "$m4a")" "$(file_sha256 "$m4a")" "skipped-existing-ok"
      fi
      return 0
    fi
    log_info "note: existing m4a failed alac/MD5; reconverting: $m4a"
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $m4a"
    log_info "would encode:         alac + audio MD5 == FLAC"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$m4a")
  tmpdir=$(make_workdir "$dest_dir")
  out="${tmpdir}/out.m4a"
  cleanup() {
    unregister_tmpdir "$tmpdir"
    rm -rf -- "$tmpdir" 2>/dev/null || true
  }

  log_progress "convert: $flac"
  if ! encode_lossless_ffmpeg "$flac" "$out" alac; then
    log_fail "$flac" "alac encode/verify failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$m4a"
  md5=$(audio_md5 "$m4a")
  sha=$(file_sha256 "$m4a")
  notes="converted"
  ((force_reconvert)) && notes="reconverted-corrupt-m4a"
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $m4a  audio_md5=$md5"
  log_success "$flac" "$m4a" "$md5" "$sha" "$notes"
  cleanup
}
