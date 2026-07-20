#!/usr/bin/env bash
# Encode FLAC → MP3 + duration/tag checks.

mp3_ok() {
  local mp3="$1"
  [[ -f "$mp3" && -s "$mp3" ]] || return 1
  [[ -n "$(audio_codec "$mp3")" ]]
}

# Encode with current MP3_FF_ARGS; map metadata/cover from FLAC.
# Duration check: use durations_match from lib/lossy.sh.
encode_mp3() {
  local flac="$1" dest="$2"
  local err
  err="$(dirname -- "$dest")/encode.err"

  if ! ffmpeg -v error -y -i "$flac" \
    -map 0:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    "${MP3_FF_ARGS[@]}" \
    -c:v copy \
    -disposition:v:0 attached_pic \
    -id3v2_version 3 \
    "$dest" 2>"$err"; then
    # Retry without video/cover if that was the failure mode
    if ! ffmpeg -v error -y -i "$flac" \
      -map 0:a:0 -map_metadata 0 \
      "${MP3_FF_ARGS[@]}" \
      -id3v2_version 3 \
      "$dest" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED encode mp3: $flac → $dest"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi
}
