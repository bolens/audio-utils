#!/usr/bin/env bash
# Multi-format tag / cover helpers (ffprobe + ffmpeg; metaflac for FLAC).

# Space-separated extensions for portable + archive audio (documentation / reuse).
# shellcheck disable=SC2034
AU_AUDIO_EXTS_DEFAULT="flac mp3 opus m4a ogg oga wma mpc aac"

# Get a metadata tag via ffprobe (format tags). Empty if missing.
audio_meta_get() {
  local file=$1 key=$2 val
  val=$(ffprobe -v error -show_entries "format_tag=${key}" -of default=nw=1:nk=1 -- "$file" 2>/dev/null | head -n1)
  # Try common case variants
  if [[ -z "$val" ]]; then
    val=$(ffprobe -v error -show_entries "format_tag=${key,,}" -of default=nw=1:nk=1 -- "$file" 2>/dev/null | head -n1)
  fi
  if [[ -z "$val" ]]; then
    val=$(ffprobe -v error -show_entries "format_tag=${key^^}" -of default=nw=1:nk=1 -- "$file" 2>/dev/null | head -n1)
  fi
  # FLAC: prefer metaflac for vorbis comments
  if [[ -z "$val" && "${file,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    val=$(flac_tag_get "$file" "$key" 2>/dev/null || true)
  fi
  printf '%s' "$(flac_tag_trim "${val:-}")"
}

# Approximate bitrate kbps (integer); empty on failure.
audio_bitrate_kbps() {
  local b
  b=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of csv=p=0 -- "$1" 2>/dev/null)
  if [[ -z "$b" || "$b" == "N/A" || "$b" == "0" ]]; then
    b=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 -- "$1" 2>/dev/null)
  fi
  if [[ -z "$b" || "$b" == "N/A" || "$b" == "0" ]]; then
    return 1
  fi
  awk -v b="$b" 'BEGIN { printf "%d\n", int(b/1000 + 0.5) }'
}

# True if file has an embedded cover (attached pic / video stream).
audio_has_cover() {
  local file=$1
  if [[ "${file,,}" == *.flac ]] && command -v metaflac >/dev/null 2>&1; then
    flac_has_picture "$file" && return 0
  fi
  local n
  n=$(ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 -- "$file" 2>/dev/null | head -n1)
  [[ -n "$n" ]]
}

# Rewrite core tags onto DEST from SRC via ffmpeg stream copy.
# Extra args: -metadata KEY=VAL ...
audio_meta_remux_tags() {
  local src=$1 dest=$2
  shift 2
  local err md5_before md5_after
  err="$(dirname -- "$dest")/meta.err"
  md5_before=$(audio_md5 "$src" 2>/dev/null || true)
  if ! ffmpeg -v error -y -i "$src" -map 0 -c copy "$@" "$dest" 2>"$err"; then
    set_last_err_file "$err"
    return 1
  fi
  if [[ -n "$md5_before" ]]; then
    md5_after=$(audio_md5 "$dest" 2>/dev/null || true)
    if [[ -n "$md5_after" && "$md5_before" != "$md5_after" ]]; then
      log_err "VERIFY FAIL (tag remux changed audio MD5)"
      return 1
    fi
  fi
  return 0
}

# Relative path of FILE under ROOT (no leading ./).
audio_relpath_under() {
  local root=$1 file=$2
  local abs_root abs_file
  abs_root=$(cd -- "$root" && pwd) || return 1
  abs_file=$(au_abspath "$file")
  case "$abs_file" in
    "$abs_root"/*) printf '%s\n' "${abs_file#"$abs_root"/}" ;;
    *) return 1 ;;
  esac
}
