#!/usr/bin/env bash
# WAV → AIFF PCM remux

_tag_pcm_from_pcm() {
  local src="$1" pcm_in="$2" pcm_out="$3"
  local err md5_before md5_after
  err="$(dirname -- "$pcm_out")/tag.err"
  md5_before=$(audio_md5 "$pcm_in")
  if ! ffmpeg -v error -y -i "$src" -i "$pcm_in" \
    -map 1:a:0 -map_metadata 0 -c:a copy \
    "$pcm_out" 2>"$err"; then
    cp -f -- "$pcm_in" "$pcm_out"
    return 0
  fi
  md5_after=$(audio_md5 "$pcm_out")
  if [[ -z "$md5_before" || "$md5_before" != "$md5_after" ]]; then
    log_err "VERIFY FAIL (pcm tag changed audio MD5)"
    return 1
  fi
}

convert_one() {
  local src="$1"
  local aiff="${src%.*}.aiff"
  local dest_dir tmpdir remuxed tagged md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$aiff" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if pcm_ok "$aiff" && sibling_matches_source "$src" "$aiff"; then
      log_progress "skip (aiff ok): $aiff"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$src" "$aiff" "$(audio_md5 "$aiff")" "$(file_sha256 "$aiff")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would remux+verify: $src -> $aiff"
    [[ "${DELETE_SOURCE:-0}" -eq 1 ]] && log_info "would delete: $src"
    return 0
  fi

  dest_dir=$(dirname -- "$aiff")
  tmpdir=$(make_workdir "$dest_dir")
  remuxed="${tmpdir}/remux.aiff"
  tagged="${tmpdir}/tagged.aiff"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $src"
  if ! remux_pcm_container "$src" "$remuxed"; then
    log_fail "$src" "remux_pcm_container failed"
    cleanup
    return 1
  fi
  if ! _tag_pcm_from_pcm "$src" "$remuxed" "$tagged"; then
    log_fail "$src" "tag copy failed"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$aiff"
  md5=$(audio_md5 "$aiff")
  sha=$(file_sha256 "$aiff")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    rm -f -- "$src"
    notes="${notes};deleted-wav"
  fi
  log_info "verified: $aiff  audio_md5=$md5"
  log_success "$src" "$aiff" "$md5" "$sha" "$notes"
  cleanup
}
