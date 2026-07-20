#!/usr/bin/env bash
# flac-to-mpc plugin — Musepack via mpcenc (lossy duration verify).

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-to-mpc}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=mpc
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=flac2mpc
AU_SUCCESS_COLUMNS='timestamp,flac,mpc,src_audio_md5,mpc_sha256,codec,bytes,samples,quality,notes'
AU_GETOPT_EXTRA="Q:N"

QUALITY_CLI="${QUALITY_CLI:-}"
MPC_QUALITY="${MPC_QUALITY:-}"
LOSSY_NO_RESAMPLE="${LOSSY_NO_RESAMPLE:-0}"

# shellcheck source=../../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/plugin_init.sh"

plugin_sibling_ok() { lossy_ok "$2"; }

plugin_consume_arg() {
  case "$1" in
    --quality)
      (($# >= 2)) || { echo "Error: --quality needs a value" >&2; exit 2; }
      QUALITY_CLI=$2
      AU_CONSUMED=2
      export AU_CONSUMED
      return 0
      ;;
    --quality=*)
      QUALITY_CLI=${1#--quality=}
      AU_CONSUMED=1
      export AU_CONSUMED
      return 0
      ;;
    --no-resample)
      LOSSY_NO_RESAMPLE=1
      AU_CONSUMED=1
      export AU_CONSUMED
      return 0
      ;;
  esac
  return 1
}

plugin_parse_opt() {
  local opt=$1 arg=${2:-}
  case "$opt" in
    Q)
      QUALITY_CLI=$arg
      return 0
      ;;
    N)
      LOSSY_NO_RESAMPLE=1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Map -Q profile to mpcenc --quality float (0–10).
mpc_resolve_quality() {
  local profile="${1,,}"
  case "$profile" in
    telephone|2|2.0) MPC_QUALITY=2.0; MPC_QUALITY_NAME=telephone ;;
    radio|4|4.0) MPC_QUALITY=4.0; MPC_QUALITY_NAME=radio ;;
    standard|normal|5|5.0|"") MPC_QUALITY=5.0; MPC_QUALITY_NAME=standard ;;
    extreme|xtreme|6|6.0) MPC_QUALITY=6.0; MPC_QUALITY_NAME=extreme ;;
    insane|7|7.0) MPC_QUALITY=7.0; MPC_QUALITY_NAME=insane ;;
    *)
      if [[ "$profile" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        MPC_QUALITY=$profile
        MPC_QUALITY_NAME=$profile
      else
        cat >&2 <<'EOF'
Error: unknown MPC quality profile.

Profiles (default: standard):
  telephone  (~60 kbps,  --quality 2)
  radio      (~130 kbps, --quality 4)
  standard   (~180 kbps, --quality 5)  [default]
  extreme    (~210 kbps, --quality 6)
  insane     (~240 kbps, --quality 7)
  Or numeric 0–10 (e.g. 5.5)

Set via: -Q PROFILE, --quality PROFILE,
         FLAC2MPC_QUALITY, or AUDIO_UTILS_MPC_QUALITY
EOF
        return 1
      fi
      ;;
  esac
  export MPC_QUALITY MPC_QUALITY_NAME
}

plugin_after_flags() {
  local raw="${QUALITY_CLI:-${FLAC2MPC_QUALITY:-${AUDIO_UTILS_MPC_QUALITY:-standard}}}"
  mpc_resolve_quality "$raw" || return 1
  export LOSSY_NO_RESAMPLE
}

plugin_banner_extra() {
  log_always "quality:   $MPC_QUALITY_NAME (mpcenc --quality $MPC_QUALITY)"
  if [[ "${LOSSY_NO_RESAMPLE:-0}" -eq 1 ]]; then
    log_always "resample:  disabled (-N)"
  fi
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock mpcenc || return 1
}

plugin_export_env() {
  export DELETE_SOURCE DELETE_FLAC="$DELETE_SOURCE"
  export MPC_QUALITY MPC_QUALITY_NAME LOSSY_NO_RESAMPLE
}
