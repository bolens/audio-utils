#!/usr/bin/env bash
# Shared PCM ↔ FLAC helpers (remux, prepare, encode, decode, tag).

flac_ok() {
  local flac="$1"
  [[ -f "$flac" && -s "$flac" ]] || return 1
  flac -t --silent "$flac" 2>/dev/null
}

# Dual remux to target PCM codec; verify hashes + sample counts.
# Args: src tmpdir target_codec [ffmpeg -af args...]
# Prints prep path on stdout (always .wav temps for FLAC friendliness).
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

# Float PCM → 24-bit with peak/scale + s24↔f32 identity checks.
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

# Map bit depth → little-endian PCM (WAV).
target_pcm_le_codec() {
  local bits
  if ! bits=$(audio_bits_per_sample "$1"); then
    log_note "note: bits_per_sample unknown; defaulting to pcm_s24le"
    echo pcm_s24le
    return 0
  fi
  case "$bits" in
    8) echo pcm_u8 ;;
    16) echo pcm_s16le ;;
    24) echo pcm_s24le ;;
    32) echo pcm_s32le ;;
    *)
      log_note "note: unusual bits_per_sample=$bits; using pcm_s24le"
      echo pcm_s24le
      ;;
  esac
}

# Map bit depth → big-endian PCM (classic AIFF).
target_pcm_be_codec() {
  local bits
  if ! bits=$(audio_bits_per_sample "$1"); then
    log_note "note: bits_per_sample unknown; defaulting to pcm_s24be"
    echo pcm_s24be
    return 0
  fi
  case "$bits" in
    8) echo pcm_u8 ;;
    16) echo pcm_s16be ;;
    24) echo pcm_s24be ;;
    32) echo pcm_s32be ;;
    *)
      log_note "note: unusual bits_per_sample=$bits; using pcm_s24be"
      echo pcm_s24be
      ;;
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

# Decode compressed lossless → PCM for FLAC encode (ALAC/WV). Prints prep .wav path.
decode_to_pcm_prep() {
  local src="$1" tmpdir="$2"
  local bits target

  if bits=$(audio_bits_per_sample "$src"); then
    case "$bits" in
      8) target=pcm_u8 ;;
      16) target=pcm_s16le ;;
      24) target=pcm_s24le ;;
      32) target=pcm_s32le ;;
      *) target=pcm_s24le ;;
    esac
  else
    target=pcm_s24le
  fi
  remux_verified "$src" "$tmpdir" "$target"
}

encode_flac() {
  local src="$1" dest="$2"
  local err
  err="$(dirname -- "$dest")/encode.err"
  if ! flac -f -8 --no-padding --silent -o "$dest" "$src" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED encode: $src → $dest"
    [[ -s "$err" ]] && { log_err "  flac stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
}

# Copy tags + cover from SRC onto FLAC without re-encoding audio.
tag_flac_from_source() {
  local src="$1" flac_in="$2" flac_out="$3"
  local err md5_before md5_after
  err="$(dirname -- "$flac_out")/tag.err"

  md5_before=$(audio_md5 "$flac_in")

  if ! ffmpeg -v error -y -i "$src" -i "$flac_in" \
    -map 1:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    -c:a copy -c:v copy \
    -disposition:v:0 attached_pic \
    "$flac_out" 2>"$err"; then
    if ! ffmpeg -v error -y -i "$src" -i "$flac_in" \
      -map 1:a:0 -map_metadata 0 -c:a copy \
      "$flac_out" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED tag/cover copy: $src"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi

  md5_after=$(audio_md5 "$flac_out")
  if [[ -z "$md5_before" || "$md5_before" != "$md5_after" ]]; then
    AUDIO_UTILS_LAST_ERR="audio_md5 before=$md5_before after=$md5_after"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (tagging changed audio MD5): $src"
    log_err "  before=$md5_before"
    log_err "  after =$md5_after"
    return 1
  fi

  log_note "tagged: metadata/cover copied from source"
}

# Back-compat alias
tag_flac() {
  tag_flac_from_source "$@"
}

# Dual-decode FLAC→PCM container; audio MD5 must match FLAC.
# Args: flac tmpdir target_codec dest_ext
# Prints decoded path on stdout.
decode_flac_verified() {
  local flac="$1" tmpdir="$2" target_codec="$3" dest_ext="${4:-wav}"
  local out1 out2 err md5_src md5_1 md5_2

  out1="$tmpdir/decode1.${dest_ext}"
  out2="$tmpdir/decode2.${dest_ext}"
  err="$tmpdir/decode.err"

  if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$target_codec" "$out1" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED decode pass1 ($target_codec): $flac"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
  if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$target_codec" "$out2" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED decode pass2 ($target_codec): $flac"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi

  md5_src=$(audio_md5 "$flac")
  md5_1=$(audio_md5 "$out1")
  md5_2=$(audio_md5 "$out2")
  if [[ -z "$md5_src" || -z "$md5_1" || -z "$md5_2" ]]; then
    AUDIO_UTILS_LAST_ERR="empty audio md5 src=$md5_src out1=$md5_1 out2=$md5_2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (empty audio MD5): $flac"
    return 1
  fi
  if [[ "$md5_1" != "$md5_2" ]]; then
    AUDIO_UTILS_LAST_ERR="pass1_md5=$md5_1 pass2_md5=$md5_2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (dual-decode audio MD5 mismatch): $flac"
    return 1
  fi
  if [[ "$md5_src" != "$md5_1" ]]; then
    AUDIO_UTILS_LAST_ERR="flac_md5=$md5_src pcm_md5=$md5_1"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (FLAC→PCM audio MD5 mismatch): $flac"
    return 1
  fi

  log_verbose "verified decode: $target_codec audio_md5=$md5_1"
  printf '%s\n' "$out1"
}

# Copy tags + cover from FLAC onto PCM container without changing audio MD5.
tag_pcm_from_flac() {
  local flac="$1" pcm_in="$2" pcm_out="$3"
  local err md5_before md5_after
  err="$(dirname -- "$pcm_out")/tag.err"

  md5_before=$(audio_md5 "$pcm_in")

  if ! ffmpeg -v error -y -i "$flac" -i "$pcm_in" \
    -map 1:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    -c:a copy -c:v copy \
    -disposition:v:0 attached_pic \
    "$pcm_out" 2>"$err"; then
    if ! ffmpeg -v error -y -i "$flac" -i "$pcm_in" \
      -map 1:a:0 -map_metadata 0 -c:a copy \
      "$pcm_out" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED tag/cover copy: $flac"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi

  md5_after=$(audio_md5 "$pcm_out")
  if [[ -z "$md5_before" || "$md5_before" != "$md5_after" ]]; then
    AUDIO_UTILS_LAST_ERR="audio_md5 before=$md5_before after=$md5_after"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (tagging changed audio MD5): $flac"
    return 1
  fi
  log_note "tagged: metadata/cover copied from source FLAC"
}

# True if path looks like a valid audio file.
pcm_ok() {
  local f="$1"
  [[ -f "$f" && -s "$f" ]] || return 1
  [[ -n "$(audio_codec "$f")" ]]
}

# Dual remux SRC → DEST PCM container (by dest extension).
# .wav/.wave → little-endian PCM; .aiff/.aif → big-endian PCM.
# Verifies pass1/pass2 and dest audio MD5 match source. Writes DEST.
remux_pcm_container() {
  local src="$1" dest="$2"
  local ext dest_dir tmpdir target_codec out1 out2 err md5_src md5_1 md5_2

  [[ -f "$src" && -n "$dest" ]] || {
    log_err "Error: remux_pcm_container requires SRC DEST"
    return 1
  }

  ext="${dest##*.}"
  ext="${ext,,}"
  case "$ext" in
    wav|wave)
      target_codec=$(target_pcm_le_codec "$src")
      ;;
    aiff|aif)
      target_codec=$(target_pcm_be_codec "$src")
      ;;
    *)
      log_err "Error: remux_pcm_container unsupported dest extension '.$ext' (want wav/aiff)"
      return 1
      ;;
  esac

  dest_dir=$(dirname -- "$dest")
  tmpdir=$(mktemp -d --tmpdir="$dest_dir" remux-pcm.XXXXXX) || return 1
  out1="${tmpdir}/pass1.${ext}"
  out2="${tmpdir}/pass2.${ext}"
  err="${tmpdir}/remux.err"

  if ! ffmpeg -v error -y -i "$src" -map 0:a:0 -c:a "$target_codec" "$out1" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED remux_pcm pass1 ($target_codec): $src"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    rm -rf -- "$tmpdir"
    return 1
  fi
  if ! ffmpeg -v error -y -i "$src" -map 0:a:0 -c:a "$target_codec" "$out2" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED remux_pcm pass2 ($target_codec): $src"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    rm -rf -- "$tmpdir"
    return 1
  fi

  md5_src=$(audio_md5 "$src")
  md5_1=$(audio_md5 "$out1")
  md5_2=$(audio_md5 "$out2")
  if [[ -z "$md5_src" || -z "$md5_1" || -z "$md5_2" ]]; then
    AUDIO_UTILS_LAST_ERR="empty audio md5 src=$md5_src out1=$md5_1 out2=$md5_2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (remux_pcm empty audio MD5): $src"
    rm -rf -- "$tmpdir"
    return 1
  fi
  if [[ "$md5_1" != "$md5_2" ]]; then
    AUDIO_UTILS_LAST_ERR="pass1_md5=$md5_1 pass2_md5=$md5_2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (remux_pcm dual audio MD5 mismatch): $src"
    rm -rf -- "$tmpdir"
    return 1
  fi
  if [[ "$md5_src" != "$md5_1" ]]; then
    AUDIO_UTILS_LAST_ERR="src_md5=$md5_src dest_md5=$md5_1 codec=$target_codec"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (remux_pcm audio MD5 != source): $src"
    rm -rf -- "$tmpdir"
    return 1
  fi

  mv -f -- "$out1" "$dest"
  rm -rf -- "$tmpdir"
  log_verbose "verified remux_pcm: $target_codec audio_md5=$md5_1 → $dest"
}

# Dual-encode FLAC from prep PCM; verify SHA + round-trip + e2e MD5.
# Sets globals via echoing nothing; returns 0 and leaves flac1 verified untagged
# in tmpdir/pass1.flac. Caller tags and moves.
# Prints: path to verified untagged flac on stdout; decoded wav path as second line
# for clean-replace use.
encode_flac_verified() {
  local src="$1" tmpdir="$2" label="${3:-source}"
  local flac1 flac2 flac3 decoded decode_err hash1 hash2 hash3 md5_flac md5_decoded md5_src

  flac1="${tmpdir}/pass1.flac"
  flac2="${tmpdir}/pass2.flac"
  flac3="${tmpdir}/roundtrip.flac"
  decoded="${tmpdir}/decoded.wav"
  decode_err="${tmpdir}/decode.err"

  if ! encode_flac "$src" "$flac1"; then
    return 1
  fi
  if ! encode_flac "$src" "$flac2"; then
    return 1
  fi

  hash1=$(file_sha256 "$flac1")
  hash2=$(file_sha256 "$flac2")
  if [[ "$hash1" != "$hash2" ]]; then
    AUDIO_UTILS_LAST_ERR="pass1=$hash1 pass2=$hash2"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (dual-encode SHA-256 mismatch): $label"
    return 1
  fi

  if ! flac -d --silent -o "$decoded" "$flac1" 2>"$decode_err"; then
    set_last_err_file "$decode_err"
    log_err "FAILED decode for verify: $label"
    return 1
  fi
  if ! encode_flac "$decoded" "$flac3"; then
    return 1
  fi

  hash3=$(file_sha256 "$flac3")
  if [[ "$hash1" != "$hash3" ]]; then
    AUDIO_UTILS_LAST_ERR="encode=$hash1 roundtrip=$hash3"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (round-trip SHA-256 mismatch): $label"
    return 1
  fi

  md5_flac=$(audio_md5 "$flac1")
  md5_decoded=$(audio_md5 "$decoded")
  if [[ -z "$md5_flac" || -z "$md5_decoded" || "$md5_flac" != "$md5_decoded" ]]; then
    AUDIO_UTILS_LAST_ERR="flac_md5=$md5_flac decoded_md5=$md5_decoded"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (audio MD5 mismatch after decode): $label"
    return 1
  fi

  md5_src=$(audio_md5 "$src")
  if [[ -z "$md5_src" || "$md5_src" != "$md5_flac" ]]; then
    AUDIO_UTILS_LAST_ERR="prep_md5=$md5_src flac_md5=$md5_flac"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (end-to-end prep→FLAC audio MD5 mismatch): $label"
    return 1
  fi
  log_verbose "verified e2e: prep audio MD5 == FLAC audio MD5 ($md5_flac)"

  if ! flac -t --silent "$flac1" 2>"$decode_err"; then
    set_last_err_file "$decode_err"
    log_err "FAILED flac -t: $label"
    return 1
  fi

  printf '%s\n' "$flac1"
  printf '%s\n' "$decoded"
  printf '%s\n' "$md5_flac"
  printf '%s\n' "$hash1"
}

# Encode FLAC → compressed lossless (alac/wavpack/ape) via ffmpeg; verify PCM MD5.
# Args: flac dest codec_name  (codec_name: alac | wavpack | ape)
# Writes dest; returns 0 if audio MD5 matches FLAC.
encode_lossless_ffmpeg() {
  local flac="$1" dest="$2" codec="$3"
  local err md5_src md5_dest
  err="$(dirname -- "$dest")/encode.err"

  if ! ffmpeg -v error -y -i "$flac" \
    -map 0:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    -c:a "$codec" -c:v copy \
    -disposition:v:0 attached_pic \
    "$dest" 2>"$err"; then
    if ! ffmpeg -v error -y -i "$flac" \
      -map 0:a:0 -map_metadata 0 \
      -c:a "$codec" \
      "$dest" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED encode $codec: $flac"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi

  md5_src=$(audio_md5 "$flac")
  md5_dest=$(audio_md5 "$dest")
  if [[ -z "$md5_src" || -z "$md5_dest" || "$md5_src" != "$md5_dest" ]]; then
    AUDIO_UTILS_LAST_ERR="flac_md5=$md5_src dest_md5=$md5_dest codec=$codec"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL ($codec audio MD5 mismatch): $flac"
    return 1
  fi
  log_verbose "verified $codec encode: audio_md5=$md5_src"
}

# True if path is ALAC audio.
is_alac() {
  [[ "$(audio_codec "$1" 2>/dev/null || true)" == "alac" ]]
}

# Reject WavPack hybrid (companion .wvc or non-wavpack codec).
is_wavpack_pure() {
  local wv="$1" base
  [[ -f "$wv" ]] || return 1
  [[ "$(audio_codec "$wv" 2>/dev/null || true)" == "wavpack" ]] || return 1
  base="${wv%.*}"
  [[ -f "${base}.wvc" || -f "${base}.WVC" ]] && return 1
  return 0
}
