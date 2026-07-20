#!/usr/bin/env bash
# aac quality profiles.

lossy_resolve_quality() {
  local profile="${1:-192}"
  profile="${profile,,}"
  LOSSY_QUALITY_NAME="$profile"
  case "$profile" in

    128|cbr128) LOSSY_QUALITY_NAME=128; LOSSY_FF_ARGS=(-codec:a aac -b:a 128k) ;;
    160|cbr160) LOSSY_QUALITY_NAME=160; LOSSY_FF_ARGS=(-codec:a aac -b:a 160k) ;;
    192|cbr192) LOSSY_QUALITY_NAME=192; LOSSY_FF_ARGS=(-codec:a aac -b:a 192k) ;;
    256|cbr256) LOSSY_QUALITY_NAME=256; LOSSY_FF_ARGS=(-codec:a aac -b:a 256k) ;;
    320|cbr320) LOSSY_QUALITY_NAME=320; LOSSY_FF_ARGS=(-codec:a aac -b:a 320k) ;;

    *)
      cat >&2 <<'EOF'
Error: unknown aac quality profile.

Profiles (default: 192):
  128 160 192 256 320  — CBR kbps via aac

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2AAC_QUALITY, or AUDIO_UTILS_AAC_QUALITY
EOF
      return 1
      ;;
  esac
  export LOSSY_QUALITY_NAME
  : "${LOSSY_FF_ARGS[@]}"
}
