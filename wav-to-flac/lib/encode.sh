#!/usr/bin/env bash
# FLAC encode + metadata/cover tagging.

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

# Copy tags + attached cover from source WAV onto FLAC without re-encoding audio.
# Verifies audio MD5 unchanged.
tag_flac() {
  local wav="$1" flac_in="$2" flac_out="$3"
  local err md5_before md5_after
  err="$(dirname -- "$flac_out")/tag.err"

  md5_before=$(audio_md5 "$flac_in")

  if ! ffmpeg -v error -y -i "$wav" -i "$flac_in" \
    -map 1:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    -c:a copy -c:v copy \
    -disposition:v:0 attached_pic \
    "$flac_out" 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED tag/cover copy: $wav"
    [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi

  md5_after=$(audio_md5 "$flac_out")
  if [[ -z "$md5_before" || "$md5_before" != "$md5_after" ]]; then
    AUDIO_UTILS_LAST_ERR="audio_md5 before=$md5_before after=$md5_after"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (tagging changed audio MD5): $wav"
    log_err "  before=$md5_before"
    log_err "  after =$md5_after"
    return 1
  fi

  log_note "tagged: metadata/cover copied from source WAV"
}
