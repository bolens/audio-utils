#!/usr/bin/env bash
# Shared PCM container → FLAC pipeline (WAV / AIFF).
#
# Uses prepare_source (float→s24, dual remux) + encode_flac_verified + tag.
# Supports -c (clean replace) and -R (retag-only) via CLEAN_WAV / RETAG_ONLY.
#
# Optional override: plugin_clean_replace SRC FLAC DECODED_WAV TMPDIR

# Re-apply tags/cover from SRC onto an existing valid sibling FLAC.
pcm_to_flac_retag_one() {
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
  log_info "  flac_sha256=$sha  audio_md5=$md5"
  log_success "$src" "$flac" "$md5" "$sha" "retag-only"
  cleanup
}

# Default clean-replace: WAV ← decoded PCM; AIFF ← ffmpeg BE PCM from FLAC.
pcm_to_flac_clean_replace() {
  local src="$1" flac="$2" decoded="$3" tmpdir="$4"
  local clean_tmp ext target clean_err

  if declare -F plugin_clean_replace >/dev/null 2>&1; then
    plugin_clean_replace "$src" "$flac" "$decoded" "$tmpdir"
    return $?
  fi

  clean_tmp="$(dirname -- "$src")/.$(basename -- "$src").clean.$$"
  ext="${src##*.}"
  ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')

  case "$ext" in
    wav | wave)
      if ! cp -f -- "$decoded" "$clean_tmp"; then
        rm -f -- "$clean_tmp"
        return 1
      fi
      ;;
    aiff | aif)
      target=$(target_pcm_be_codec "$flac")
      clean_err="${tmpdir}/clean.err"
      if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$target" "$clean_tmp" 2>"$clean_err"; then
        set_last_err_file "$clean_err"
        rm -f -- "$clean_tmp"
        return 1
      fi
      ;;
    *)
      log_err "clean replace: unsupported extension .$ext"
      return 1
      ;;
  esac

  if ! mv -f -- "$clean_tmp" "$src"; then
    rm -f -- "$clean_tmp"
    return 1
  fi
  return 0
}

pcm_to_flac_convert_one() {
  local src="$1"
  local flac="${src%.*}.flac"
  local dest_dir tmpdir flac_tagged prep decoded
  local md5_flac hash1 codec notes=""
  local force_reconvert=0
  local src_label="${AU_SOURCE_LABEL:-${AU_SOURCE_EXT:-src}}"
  local -a enc_out

  if [[ "${RETAG_ONLY:-0}" -eq 1 ]]; then
    pcm_to_flac_retag_one "$src"
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
    log_info "would tag:            copy metadata/cover from source → FLAC"
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
    log_fail "$src" "prepare/remux failed (missing prep)" "got=${prep:-empty} tmpdir=$tmpdir"
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
  decoded=${enc_out[1]}
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
  log_info "  codec=$(audio_codec "$src" || echo '?')  size=$(human_bytes "$(file_bytes "$src")")"

  notes="converted"
  if ((force_reconvert)); then
    notes="reconverted-corrupt-flac"
  fi

  if [[ "${DELETE_SOURCE:-${DELETE_WAV:-0}}" -eq 1 ]]; then
    rm -f -- "$src"
    log_info "deleted: $src"
    notes="${notes};deleted-${src_label}"
  elif [[ "${CLEAN_WAV:-0}" -eq 1 ]]; then
    if ! pcm_to_flac_clean_replace "$src" "$flac" "$decoded" "$tmpdir"; then
      log_fail "$src" "clean replace failed (flac kept)"
      cleanup
      return 1
    fi
    log_info "cleaned: $src (PCM from FLAC; matches FLAC)"
    notes="${notes};cleaned-${src_label}"
  fi

  log_success "$src" "$flac" "$md5_flac" "$(file_sha256 "$flac")" "$notes"
  cleanup
}

# --- plugin hooks (-c / -R) -------------------------------------------------

pcm_to_flac_plugin_parse_opt() {
  local opt=$1
  case "$opt" in
    c) CLEAN_WAV=1; return 0 ;;
    R) RETAG_ONLY=1; return 0 ;;
    *) return 1 ;;
  esac
}

pcm_to_flac_plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 && "${CLEAN_WAV:-0}" -eq 1 ]]; then
    echo "Note: -d set; -c ignored (source will be deleted, not cleaned)." >&2
    CLEAN_WAV=0
  fi
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    if [[ "${RETAG_ONLY:-0}" -eq 1 || "${CLEAN_WAV:-0}" -eq 1 ]]; then
      echo "Note: -D is cleanup-only; -R/-c ignored." >&2
    fi
    RETAG_ONLY=0
    CLEAN_WAV=0
  fi
  if [[ "${RETAG_ONLY:-0}" -eq 1 && ( "${DELETE_SOURCE:-0}" -eq 1 || "${CLEAN_WAV:-0}" -eq 1 ) ]]; then
    echo "Note: -R set; -d/-c ignored." >&2
    DELETE_SOURCE=0
    CLEAN_WAV=0
  fi
}

pcm_to_flac_plugin_export_env() {
  export DELETE_SOURCE DELETE_WAV="$DELETE_SOURCE"
  export CLEAN_WAV RETAG_ONLY
}

# Wire convert_one + -c/-R hooks after plugin_init (expects CLEAN_WAV/RETAG_ONLY set).
pcm_to_flac_plugin_wire() {
  CLEAN_WAV="${CLEAN_WAV:-0}"
  RETAG_ONLY="${RETAG_ONLY:-0}"
  # Drivers call these by name; shellcheck cannot see the indirection.
  # shellcheck disable=SC2329
  convert_one() { pcm_to_flac_convert_one "$@"; }
  # shellcheck disable=SC2329
  plugin_sibling_ok() { flac_ok "$2"; }
  # shellcheck disable=SC2329
  plugin_parse_opt() { pcm_to_flac_plugin_parse_opt "$@"; }
  # shellcheck disable=SC2329
  plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
  # shellcheck disable=SC2329
  plugin_after_flags() { pcm_to_flac_plugin_after_flags; }
  # shellcheck disable=SC2329
  plugin_export_env() { pcm_to_flac_plugin_export_env; }
}
