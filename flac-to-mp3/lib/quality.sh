#!/usr/bin/env bash
# MP3 quality profiles (libmp3lame).

# Resolve profile name → sets MP3_FF_ARGS array and MP3_QUALITY_NAME.
# Returns 1 on unknown profile (prints table to stderr).
mp3_resolve_quality() {
  local profile="${1:-v0}"
  profile="${profile,,}"
  MP3_QUALITY_NAME="$profile"
  case "$profile" in
    v0|vbr0)
      MP3_QUALITY_NAME=v0
      MP3_FF_ARGS=(-codec:a libmp3lame -q:a 0)
      ;;
    v2|vbr2)
      MP3_QUALITY_NAME=v2
      MP3_FF_ARGS=(-codec:a libmp3lame -q:a 2)
      ;;
    320|cbr320)
      MP3_QUALITY_NAME=320
      MP3_FF_ARGS=(-codec:a libmp3lame -b:a 320k)
      ;;
    192|cbr192)
      MP3_QUALITY_NAME=192
      MP3_FF_ARGS=(-codec:a libmp3lame -b:a 192k)
      ;;
    *)
      cat >&2 <<'EOF'
Error: unknown MP3 quality profile.

Profiles (suggested default: v0):
  v0   VBR V0  — libmp3lame -q:a 0  (best library quality/size)
  v2   VBR V2  — libmp3lame -q:a 2
  320  CBR 320k
  192  CBR 192k

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2MP3_QUALITY, or AUDIO_UTILS_MP3_QUALITY
EOF
      return 1
      ;;
  esac
  export MP3_QUALITY_NAME
  # Array used by encode_mp3 / convert_one (cannot export arrays).
  : "${MP3_FF_ARGS[@]}"
}

# True if ffmpeg has libmp3lame.
require_libmp3lame() {
  local out
  # Avoid pipefail+SIGPIPE false negatives from `grep -q` closing early.
  out=$(ffmpeg -hide_banner -encoders 2>/dev/null) || true
  if [[ "$out" == *libmp3lame* ]]; then
    return 0
  fi
  log_err "Error: ffmpeg lacks libmp3lame encoder (install lame / ffmpeg with mp3)."
  return 1
}
