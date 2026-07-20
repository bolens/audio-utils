#!/usr/bin/env bash
# Shared lossless convert pipelines (container codecs ↔ FLAC, FLAC → PCM).
#
# to_flac_convert_one:
#   Decode source → PCM prep → dual FLAC encode → tag → sibling .flac
#   Optional: plugin_decode_prep SRC TMPDIR  (prints prep path; default decode_to_pcm_prep)
#   Optional: AU_SOURCE_LABEL for delete notes (default AU_SOURCE_EXT)
#   Optional: AU_TAG_FROM_SOURCE=0 to skip tagging (copy untagged)
#
# from_flac_lossless_convert_one:
#   Requires AU_LOSSLESS_CODEC (alac|wavpack|ape|tta) and AU_DEST_EXT
#   Skip via plugin_sibling_ok (or sibling_ok)
#   Optional: plugin_post_encode_ok DEST (e.g. is_wavpack_pure)
#
# flac_to_pcm_convert_one:
#   Requires AU_DEST_EXT (wav|aiff|aif|caf)
#   Skip via pcm_ok + sibling MD5

# True if path is Monkey's Audio.
is_ape() {
  [[ "$(audio_codec "$1" 2>/dev/null || true)" == "ape" ]]
}

# True if path is True Audio (TTA).
is_tta() {
  [[ "$(audio_codec "$1" 2>/dev/null || true)" == "tta" ]]
}

# True if path is Shorten.
is_shorten() {
  [[ "$(audio_codec "$1" 2>/dev/null || true)" == "shorten" ]]
}

# --- * → FLAC ----------------------------------------------------------------

to_flac_convert_one() {
  local src="$1"
  local flac="${src%.*}.flac"
  local dest_dir tmpdir flac_tagged prep
  local md5_flac hash1 notes=""
  local force_reconvert=0
  local src_label="${AU_SOURCE_LABEL:-${AU_SOURCE_EXT:-src}}"
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

  if declare -F plugin_decode_prep >/dev/null 2>&1; then
    if ! plugin_decode_prep "$src" "$tmpdir" >"${tmpdir}/prep.path"; then
      log_fail "$src" "decode to PCM failed"
      cleanup
      return 1
    fi
  else
    if ! decode_to_pcm_prep "$src" "$tmpdir" >"${tmpdir}/prep.path"; then
      log_fail "$src" "decode to PCM failed"
      cleanup
      return 1
    fi
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

  if [[ "${AU_TAG_FROM_SOURCE:-1}" -eq 0 ]]; then
    cp -f -- "${enc_out[0]}" "$flac_tagged"
  elif ! tag_flac_from_source "$src" "${enc_out[0]}" "$flac_tagged" 2>/dev/null; then
    cp -f -- "${enc_out[0]}" "$flac_tagged"
  fi

  mv -f -- "$flac_tagged" "$flac"
  notes="converted"
  if ((force_reconvert)); then
    notes="reconverted"
  fi
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    rm -f -- "$src"
    notes="${notes};deleted-${src_label}"
  fi
  log_info "verified: $flac  audio_md5=$md5_flac sha=$hash1"
  log_success "$src" "$flac" "$md5_flac" "$(file_sha256 "$flac")" "$notes"
  cleanup
}

# --- FLAC → compressed lossless ---------------------------------------------

from_flac_lossless_convert_one() {
  local flac="$1"
  local dest_ext="${AU_DEST_EXT:?AU_DEST_EXT required}"
  local codec="${AU_LOSSLESS_CODEC:?AU_LOSSLESS_CODEC required}"
  local dest="${flac%.*}.${dest_ext}"
  local dest_dir tmpdir out md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$dest" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if sibling_ok "$flac" "$dest"; then
      log_progress "skip (${dest_ext} ok): $dest"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$dest" "$(audio_md5 "$dest")" "$(file_sha256 "$dest")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $dest"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$dest")
  tmpdir=$(make_workdir "$dest_dir")
  out="${tmpdir}/out.${dest_ext}"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac"
  if ! encode_lossless_ffmpeg "$flac" "$out" "$codec"; then
    log_fail "$flac" "${codec} encode/verify failed" "tmpdir=$tmpdir"
    cleanup
    return 1
  fi

  if declare -F plugin_post_encode_ok >/dev/null 2>&1; then
    if ! plugin_post_encode_ok "$out"; then
      log_fail "$flac" "encoded ${dest_ext} failed post-check" "out=$out"
      cleanup
      return 1
    fi
  fi

  mv -f -- "$out" "$dest"
  md5=$(audio_md5 "$dest")
  sha=$(file_sha256 "$dest")
  notes="converted"
  if ((force_reconvert)); then
    notes="reconverted"
  fi
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $dest  audio_md5=$md5"
  log_success "$flac" "$dest" "$md5" "$sha" "$notes"
  cleanup
}

# --- FLAC → PCM (wav/aiff) --------------------------------------------------

flac_to_pcm_convert_one() {
  local flac="$1"
  local dest_ext="${AU_DEST_EXT:?AU_DEST_EXT required}"
  local dest="${flac%.*}.${dest_ext}"
  local dest_dir tmpdir target tagged pcm md5 sha notes=""
  local force_reconvert=0

  if [[ -f "$dest" && "${OVERWRITE:-0}" -eq 0 ]]; then
    if pcm_ok "$dest" && sibling_matches_source "$flac" "$dest"; then
      log_progress "skip (${dest_ext} ok): $dest"
      if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
        log_success "$flac" "$dest" "$(audio_md5 "$dest")" "$(file_sha256 "$dest")" "skipped-existing-ok"
      fi
      return 0
    fi
    force_reconvert=1
  fi

  case "${dest_ext,,}" in
    wav|wave) target=$(target_pcm_le_codec "$flac" 2>/dev/null || echo pcm_s24le) ;;
    aiff|aif) target=$(target_pcm_be_codec "$flac" 2>/dev/null || echo pcm_s24be) ;;
    caf) target=$(target_pcm_le_codec "$flac" 2>/dev/null || echo pcm_s24le) ;;
    *)
      log_fail "$flac" "unsupported AU_DEST_EXT for flac_to_pcm: $dest_ext"
      return 1
      ;;
  esac

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would convert+verify: $flac -> $dest"
    log_info "would decode:         flac → $target (dual + audio MD5)"
    [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]] && log_info "would delete: $flac"
    return 0
  fi

  if ! flac -t --silent "$flac" 2>/dev/null; then
    log_fail "$flac" "flac -t failed" "source corrupt or unreadable"
    return 1
  fi

  dest_dir=$(dirname -- "$dest")
  tmpdir=$(make_workdir "$dest_dir")
  tagged="${tmpdir}/tagged.${dest_ext}"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "convert: $flac"
  case "${dest_ext,,}" in
    wav|wave|caf) target=$(target_pcm_le_codec "$flac") ;;
    aiff|aif) target=$(target_pcm_be_codec "$flac") ;;
  esac

  if ! decode_flac_verified "$flac" "$tmpdir" "$target" "$dest_ext" >"${tmpdir}/decode.path"; then
    log_fail "$flac" "decode/verify failed" "codec=$target tmpdir=$tmpdir"
    cleanup
    return 1
  fi
  pcm=$(tail -n1 "${tmpdir}/decode.path")
  [[ -f "$pcm" ]] || { log_fail "$flac" "decode missing output"; cleanup; return 1; }

  if ! tag_pcm_from_flac "$flac" "$pcm" "$tagged"; then
    log_fail "$flac" "tag/cover copy failed"
    cleanup
    return 1
  fi

  mv -f -- "$tagged" "$dest"
  md5=$(audio_md5 "$dest")
  sha=$(file_sha256 "$dest")
  notes="converted;$target"
  if ((force_reconvert)); then
    notes="reconverted;$target"
  fi
  if [[ "${DELETE_SOURCE:-${DELETE_FLAC:-0}}" -eq 1 ]]; then
    rm -f -- "$flac"
    notes="${notes};deleted-flac"
  fi
  log_info "verified: $dest  audio_md5=$md5  pcm=$target"
  log_success "$flac" "$dest" "$md5" "$sha" "$notes"
  cleanup
}

# --- multi-stream extract → .aN.flac ----------------------------------------

audio_stream_count() {
  ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$1" 2>/dev/null | grep -c . || true
}

# Extract one audio stream to DEST flac (verified). Args: SRC INDEX DEST TMPDIR
# Optional AU_STREAM_TAG=1 to map stream metadata (best-effort).
extract_audio_stream_to_flac() {
  local src="$1" idx="$2" dest="$3" tmpdir="$4"
  local wav="${tmpdir}/a${idx}.wav"
  local -a enc_out
  local md5_flac

  if [[ -f "$dest" && "${OVERWRITE:-0}" -eq 0 ]] && flac_ok "$dest"; then
    log_progress "skip (flac ok): $dest"
    if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
      log_success "$src" "$dest" "$(audio_md5 "$dest")" "$(file_sha256 "$dest")" "skipped-existing-ok;stream=$idx"
    fi
    return 0
  fi

  if ! ffmpeg -v error -y -i "$src" -map "0:a:${idx}" -c:a pcm_s24le "$wav" 2>"${tmpdir}/extract.err"; then
    set_last_err_file "${tmpdir}/extract.err"
    log_fail "$src" "extract stream a:$idx failed"
    return 1
  fi

  if ! encode_flac_verified "$wav" "$tmpdir" "$src#a$idx" >"${tmpdir}/enc.out"; then
    log_fail "$src" "encode stream a:$idx failed"
    return 1
  fi
  mapfile -t enc_out <"${tmpdir}/enc.out"
  md5_flac=${enc_out[2]}

  if [[ "${AU_STREAM_TAG:-0}" -eq 1 ]]; then
    if ! ffmpeg -v error -y -i "$src" -i "${enc_out[0]}" \
      -map 1:a:0 -map_metadata 0:s:a:"$idx" -c:a copy \
      "${tmpdir}/tagged.flac" 2>"${tmpdir}/tag.err"; then
      cp -f -- "${enc_out[0]}" "${tmpdir}/tagged.flac"
    fi
    mv -f -- "${tmpdir}/tagged.flac" "$dest"
  else
    mv -f -- "${enc_out[0]}" "$dest"
  fi

  log_info "verified: $dest  audio_md5=$md5_flac"
  log_success "$src" "$dest" "$md5_flac" "$(file_sha256 "$dest")" "converted;stream=$idx"
  rm -f -- "$wav" 2>/dev/null || true
}
