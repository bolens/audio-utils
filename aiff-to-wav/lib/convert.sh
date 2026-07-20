#!/usr/bin/env bash
# AIFF → WAV PCM remux

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
  local wav="${src%.*}.wav"
  local dest_dir tmpdir remuxed tagged md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$wav" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if pcm_ok "$wav" && sibling_matches_source "$src" "$wav"; then
      log_progress "skip (wav ok): $wav"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$src" "$wav" "$(audio_md5 "$wav")" "$(file_sha256 "$wav")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would remux+verify: $src -> $wav"
    [[ "${DELETE_SOURCE:-0}" -eq 1 ]] && log_info "would delete: $src"
    return 0
  fi

  dest_dir=$(dirname -- "$wav")
  tmpdir=$(make_workdir "$dest_dir")
  remuxed="${tmpdir}/remux.wav"
  tagged="${tmpdir}/tagged.wav"
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

  mv -f -- "$tagged" "$wav"
  md5=$(audio_md5 "$wav")
  sha=$(file_sha256 "$wav")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    rm -f -- "$src"
    notes="${notes};deleted-aiff"
  fi
  log_info "verified: $wav  audio_md5=$md5"
  log_success "$src" "$wav" "$md5" "$sha" "$notes"
  cleanup
}
