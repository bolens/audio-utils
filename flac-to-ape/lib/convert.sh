#!/usr/bin/env bash
# FLAC → APE

convert_one() {
  local flac="$1"
  local ape="${flac%.*}.ape"
  local dest_dir tmpdir out md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$ape" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if [[ "$(audio_codec "$ape" 2>/dev/null || true)" == "ape" ]] && sibling_matches_source "$flac" "$ape"; then
      log_progress "skip (ape ok): $ape"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$ape" "$(audio_md5 "$ape")" "$(file_sha256 "$ape")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $ape"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$ape")
  tmpdir=$(make_workdir "$dest_dir")
  out="${tmpdir}/out.ape"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac"
  if ! encode_lossless_ffmpeg "$flac" "$out" ape; then
    log_fail "$flac" "ape encode/verify failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  mv -f -- "$out" "$ape"
  md5=$(audio_md5 "$ape")
  sha=$(file_sha256 "$ape")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $ape  audio_md5=$md5"
  log_success "$flac" "$ape" "$md5" "$sha" "$notes"
  cleanup
}
