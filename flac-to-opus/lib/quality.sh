#!/usr/bin/env bash
# opus quality profiles.

lossy_resolve_quality() {
  local profile="${1:-128}"
  profile="${profile,,}"
  LOSSY_QUALITY_NAME="$profile"
  case "$profile" in

    64|cbr64) LOSSY_QUALITY_NAME=64; LOSSY_FF_ARGS=(-codec:a libopus -b:a 64k) ;;
    96|cbr96) LOSSY_QUALITY_NAME=96; LOSSY_FF_ARGS=(-codec:a libopus -b:a 96k) ;;
    128|cbr128) LOSSY_QUALITY_NAME=128; LOSSY_FF_ARGS=(-codec:a libopus -b:a 128k) ;;
    160|cbr160) LOSSY_QUALITY_NAME=160; LOSSY_FF_ARGS=(-codec:a libopus -b:a 160k) ;;
    192|cbr192) LOSSY_QUALITY_NAME=192; LOSSY_FF_ARGS=(-codec:a libopus -b:a 192k) ;;
    256|cbr256) LOSSY_QUALITY_NAME=256; LOSSY_FF_ARGS=(-codec:a libopus -b:a 256k) ;;

    *)
      cat >&2 <<'EOF'
Error: unknown opus quality profile.

Profiles (default: 128):
  64 96 128 160 192 256  — CBR kbps via libopus

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2OPUS_QUALITY, or AUDIO_UTILS_OPUS_QUALITY
EOF
      return 1
      ;;
  esac
  export LOSSY_QUALITY_NAME
  : "${LOSSY_FF_ARGS[@]}"
}
