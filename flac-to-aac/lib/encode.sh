#!/usr/bin/env bash
# Encode FLAC → m4a

m4a_ok() {
  local f="$1"
  [[ -f "$f" && -s "$f" ]] || return 1
  [[ -n "$(audio_codec "$f")" ]]
}

encode_aac() {
  local src="$1" dest="$2"
  local err
  err="$(dirname -- "$dest")/encode.err"

  if ! ffmpeg -v error -y -i "$src" \
    -map 0:a:0 -map "0:v:0?" \
    -map_metadata 0 \
    "${LOSSY_FF_ARGS[@]}" \
    -c:v copy \
    -disposition:v:0 attached_pic \
    "$dest" 2>"$err"; then
    if ! ffmpeg -v error -y -i "$src" \
      -map 0:a:0 -map_metadata 0 \
      "${LOSSY_FF_ARGS[@]}" \
      "$dest" 2>"$err"; then
      set_last_err_file "$err"
      log_err "FAILED encode aac: $src → $dest"
      [[ -s "$err" ]] && { log_err "  ffmpeg stderr:"; sed 's/^/  | /' "$err" >&2; }
      return 1
    fi
  fi
}
