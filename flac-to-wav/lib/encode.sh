#!/usr/bin/env bash
# Decode FLAC → WAV + tag/cover copy.

# Map FLAC bit depth to little-endian PCM codec.
target_wav_codec() {
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

# Dual-decode FLAC→WAV; audio MD5 of both passes must match source FLAC.
# Prints prep wav path on stdout.
decode_flac_verified() {
  local flac="$1" tmpdir="$2" target_codec="$3"
  local wav1 wav2 err md5_src md5_1 md5_2

  wav1="$tmpdir/decode1.wav"
  wav2="$tmpdir/decode2.wav"
  err="$tmpdir/decode.err"

  if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$target_codec" "$wav1" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED decode pass1 ($target_codec): $flac"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
  if ! ffmpeg -v error -y -i "$flac" -map 0:a:0 -c:a "$target_codec" "$wav2" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED decode pass2 ($target_codec): $flac"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi

  md5_src=$(audio_md5 "$flac")
  md5_1=$(audio_md5 "$wav1")
  md5_2=$(audio_md5 "$wav2")
  if [[ -z "$md5_src" || -z "$md5_1" || -z "$md5_2" ]]; then
    AUDIO_UTILS_LAST_ERR="empty audio md5 src=$md5_src wav1=$md5_1 wav2=$md5_2"
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
    AUDIO_UTILS_LAST_ERR="flac_md5=$md5_src wav_md5=$md5_1"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (FLAC→WAV audio MD5 mismatch): $flac"
    return 1
  fi

  log_verbose "verified decode: $target_codec audio_md5=$md5_1"
  printf '%s\n' "$wav1"
}

# Copy tags + cover from FLAC onto WAV without changing audio MD5.
tag_wav() {
  local flac="$1" wav_in="$2" wav_out="$3"
  local err md5_before md5_after
  err="$(dirname -- "$wav_out")/tag.err"

  md5_before=$(audio_md5 "$wav_in")

  if ! ffmpeg -v error -y -i "$flac" -i "$wav_in" \
    -map 1:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    -c:a copy -c:v copy \
    -disposition:v:0 attached_pic \
    "$wav_out" 2>"$err"; then
    # Fallback: audio-only metadata if cover map fails
    if ! ffmpeg -v error -y -i "$flac" -i "$wav_in" \
      -map 1:a:0 -map_metadata 0 -c:a copy \
      "$wav_out" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED tag/cover copy: $flac"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi

  md5_after=$(audio_md5 "$wav_out")
  if [[ -z "$md5_before" || "$md5_before" != "$md5_after" ]]; then
    AUDIO_UTILS_LAST_ERR="audio_md5 before=$md5_before after=$md5_after"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (tagging changed audio MD5): $flac"
    return 1
  fi
  log_note "tagged: metadata/cover copied from source FLAC"
}

# True if WAV looks like a valid audio file.
wav_ok() {
  local wav="$1"
  [[ -f "$wav" && -s "$wav" ]] || return 1
  [[ -n "$(audio_codec "$wav")" ]]
}
