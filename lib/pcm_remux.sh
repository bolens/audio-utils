#!/usr/bin/env bash
# PCM container remux (WAV ↔ AIFF): copy audio, map tags, verify MD5.
#
# Requires: AU_DEST_EXT (wav|aiff|aif)
# Optional: AU_SOURCE_LABEL for delete notes (default: AU_SOURCE_EXT)
#
# convert_one → pcm_remux_convert_one

# Copy metadata from SRC onto PCM_IN → PCM_OUT without touching audio.
# Falls back to plain copy if ffmpeg metadata map fails.
tag_pcm_from_pcm() {
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

pcm_remux_convert_one() {
  local src="$1"
  local dest_ext="${AU_DEST_EXT:?AU_DEST_EXT required}"
  local dest="${src%.*}.${dest_ext}"
  local dest_dir tmpdir remuxed tagged md5 sha notes=""
  local force_reconvert=0
  local src_label="${AU_SOURCE_LABEL:-${AU_SOURCE_EXT:-src}}"

  if [[ -f "$dest" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if pcm_ok "$dest" && sibling_matches_source "$src" "$dest"; then
      log_progress "skip (${dest_ext} ok): $dest"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$src" "$dest" "$(audio_md5 "$dest")" "$(file_sha256 "$dest")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would remux+verify: $src -> $dest"
    [[ "${DELETE_SOURCE:-0}" -eq 1 ]] && log_info "would delete: $src"
    return 0
  fi

  dest_dir=$(dirname -- "$dest")
  tmpdir=$(make_workdir "$dest_dir")
  remuxed="${tmpdir}/remux.${dest_ext}"
  tagged="${tmpdir}/tagged.${dest_ext}"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $src"
  if ! remux_pcm_container "$src" "$remuxed"; then
    log_fail "$src" "remux_pcm_container failed"
    cleanup
    return 1
  fi
  if ! tag_pcm_from_pcm "$src" "$remuxed" "$tagged"; then
    log_fail "$src" "tag copy failed"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$dest"
  md5=$(audio_md5 "$dest")
  sha=$(file_sha256 "$dest")
  notes="converted"
  ((force_reconvert)) && notes="reconverted"
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    rm -f -- "$src"
    notes="${notes};deleted-${src_label}"
  fi
  log_info "verified: $dest  audio_md5=$md5"
  log_success "$src" "$dest" "$md5" "$sha" "$notes"
  cleanup
}
