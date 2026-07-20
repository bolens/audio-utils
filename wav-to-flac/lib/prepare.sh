#!/usr/bin/env bash
# Clean PCM remux / float→int preparation before FLAC encode.

# Dual remux to target PCM codec; verify hashes + sample counts.
# Args: wav tmpdir target_codec [ffmpeg -af args...]
# Prints prep path on stdout.
remux_verified() {
  local wav="$1" tmpdir="$2" target_codec="$3"
  shift 3
  local -a extra_args=("$@")
  local prep1 prep2 err hash1 hash2 md5_1 md5_2 samples_src samples_prep
  local -a ff_common

  prep1="$tmpdir/prep1.wav"
  prep2="$tmpdir/prep2.wav"
  err="$tmpdir/prep.err"
  ff_common=( -v error -y -i "$wav" -map 0:a:0 )
  if ((${#extra_args[@]})); then
    ff_common+=("${extra_args[@]}")
  fi

  if ! ffmpeg "${ff_common[@]}" -c:a "$target_codec" "$prep1" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED remux pass1 ($target_codec): $wav"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
  if ! ffmpeg "${ff_common[@]}" -c:a "$target_codec" "$prep2" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED remux pass2 ($target_codec): $wav"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi

  hash1=$(file_sha256 "$prep1")
  hash2=$(file_sha256 "$prep2")
  if [[ "$hash1" != "$hash2" ]]; then
    AUDIO_UTILS_LAST_ERR="pass1_sha256=$hash1 pass2_sha256=$hash2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (remux dual SHA-256 mismatch): $wav"
    log_err "  pass1=$hash1"
    log_err "  pass2=$hash2"
    return 1
  fi

  md5_1=$(audio_md5 "$prep1")
  md5_2=$(audio_md5 "$prep2")
  if [[ -z "$md5_1" || "$md5_1" != "$md5_2" ]]; then
    AUDIO_UTILS_LAST_ERR="pass1_md5=$md5_1 pass2_md5=$md5_2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (remux dual audio MD5 mismatch): $wav"
    log_err "  pass1=$md5_1"
    log_err "  pass2=$md5_2"
    return 1
  fi

  samples_src=$(audio_samples "$wav")
  samples_prep=$(audio_samples "$prep1")
  if [[ -z "$samples_prep" ]]; then
    log_err "VERIFY FAIL (remux sample count unreadable): $wav"
    return 1
  fi
  if [[ -n "$samples_src" && "$samples_src" != "$samples_prep" ]]; then
    log_note "note: sample count src=$samples_src prep=$samples_prep (container junk trimmed)"
  fi

  log_verbose "verified remux: $target_codec samples=$samples_prep audio_md5=$md5_1"
  printf '%s\n' "$prep1"
}

# Float WAV → 24-bit PCM with peak/scale + s24↔f32 identity checks.
prepare_float() {
  local wav="$1" tmpdir="$2" codec="$3"
  local peak gain prep rt_f prep_rt err hash1 hash3 peak_prep

  log_note "note: $codec → pcm_s24le (FLAC requires integer PCM; 24-bit matches float precision)"

  if ! peak=$(float_abs_peak "$wav"); then
    AUDIO_UTILS_LAST_ERR="float_abs_peak failed (NaN/Inf or unreadable)"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (float source has NaN/Inf or unreadable peak): $wav"
    return 1
  fi

  if awk -v p="$peak" 'BEGIN { exit !(p > 1.0) }'; then
    gain=$(awk -v p="$peak" 'BEGIN { printf "%.12f", 1.0 / p }')
    log_note "note: float peak $peak > 1.0; scaling ×$gain to prevent clipping"
    if ! remux_verified "$wav" "$tmpdir" pcm_s24le -af "volume=${gain}" >"${tmpdir}/remux.path"; then
      return 1
    fi
  else
    log_note "note: float peak $peak ≤ 1.0 (no scale needed)"
    if ! remux_verified "$wav" "$tmpdir" pcm_s24le >"${tmpdir}/remux.path"; then
      return 1
    fi
  fi

  prep=$(tail -n1 "${tmpdir}/remux.path")

  rt_f="$tmpdir/prep-rt-f32.wav"
  prep_rt="$tmpdir/prep-rt-s24.wav"
  err="$tmpdir/prep-rt.err"
  hash1=$(file_sha256 "$prep")

  if ! ffmpeg -v error -y -i "$prep" -c:a pcm_f32le "$rt_f" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED float→int round-trip (s24→f32): $wav"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
  if ! ffmpeg -v error -y -i "$rt_f" -c:a pcm_s24le "$prep_rt" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED float→int round-trip (f32→s24): $wav"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
  hash3=$(file_sha256 "$prep_rt")
  if [[ "$hash1" != "$hash3" ]]; then
    AUDIO_UTILS_LAST_ERR="prep_sha256=$hash1 roundtrip_sha256=$hash3"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (s24↔f32 round-trip SHA-256 mismatch): $wav"
    log_err "  prep     =$hash1"
    log_err "  roundtrip=$hash3"
    return 1
  fi

  if ! peak_prep=$(float_abs_peak "$rt_f"); then
    AUDIO_UTILS_LAST_ERR="float_abs_peak failed on round-trip float"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (prep peak unreadable): $wav"
    return 1
  fi
  if awk -v p="$peak_prep" 'BEGIN { exit !(p > 1.0) }'; then
    AUDIO_UTILS_LAST_ERR="prep_peak=$peak_prep (still > 1.0 after scale)"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (prep still peaks above 1.0 after scale: $peak_prep): $wav"
    return 1
  fi

  log_verbose "verified float prep: peak=$peak_prep"
  printf '%s\n' "$prep"
}

# Normalize endianness to little-endian for FLAC friendliness
target_pcm_codec() {
  case "$1" in
    pcm_s16be) echo pcm_s16le ;;
    pcm_s24be) echo pcm_s24le ;;
    pcm_s32be) echo pcm_s32le ;;
    pcm_u8|pcm_s16le|pcm_s24le|pcm_s32le) echo "$1" ;;
    *) return 1 ;;
  esac
}

# Always remux to clean PCM; returns prep path on stdout.
prepare_source() {
  local wav="$1" tmpdir="$2"
  local codec target

  codec=$(audio_codec "$wav")
  if [[ -z "$codec" ]]; then
    AUDIO_UTILS_LAST_ERR="ffprobe returned empty codec_name"
    export AUDIO_UTILS_LAST_ERR
    log_err "FAILED: cannot probe audio codec: $wav"
    return 1
  fi

  case "$codec" in
    pcm_f16le|pcm_f16be|pcm_f24le|pcm_f24be|pcm_f32le|pcm_f32be|pcm_f64le|pcm_f64be)
      prepare_float "$wav" "$tmpdir" "$codec"
      ;;
    pcm_*)
      if ! target=$(target_pcm_codec "$codec"); then
        AUDIO_UTILS_LAST_ERR="unsupported integer PCM codec=$codec"
        export AUDIO_UTILS_LAST_ERR
        log_err "FAILED: unsupported integer PCM codec '$codec': $wav"
        return 1
      fi
      if [[ "$target" != "$codec" ]]; then
        log_note "note: $codec → $target (endian normalize + clean remux)"
      else
        log_note "note: $codec clean remux (strip container junk)"
      fi
      remux_verified "$wav" "$tmpdir" "$target"
      ;;
    *)
      AUDIO_UTILS_LAST_ERR="unsupported non-PCM codec=$codec"
      export AUDIO_UTILS_LAST_ERR
      log_err "FAILED: unsupported codec '$codec' (not PCM): $wav"
      return 1
      ;;
  esac
}
