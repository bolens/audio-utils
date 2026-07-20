#!/usr/bin/env bash
# vorbis quality profiles.

lossy_resolve_quality() {
  local profile="${1:-q6}"
  profile="${profile,,}"
  LOSSY_QUALITY_NAME="$profile"
  case "$profile" in

    q4|4) LOSSY_QUALITY_NAME=q4; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 4) ;;
    q5|5) LOSSY_QUALITY_NAME=q5; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 5) ;;
    q6|6) LOSSY_QUALITY_NAME=q6; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 6) ;;
    q7|7) LOSSY_QUALITY_NAME=q7; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 7) ;;
    q8|8) LOSSY_QUALITY_NAME=q8; LOSSY_FF_ARGS=(-codec:a libvorbis -q:a 8) ;;

    *)
      cat >&2 <<'EOF'
Error: unknown vorbis quality profile.

Profiles (default: q6):
  q4 q5 q6 q7 q8  — libvorbis -q:a N

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2VORBIS_QUALITY, or AUDIO_UTILS_VORBIS_QUALITY
EOF
      return 1
      ;;
  esac
  export LOSSY_QUALITY_NAME
  : "${LOSSY_FF_ARGS[@]}"
}
