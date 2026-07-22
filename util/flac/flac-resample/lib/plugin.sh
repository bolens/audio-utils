#!/usr/bin/env bash
# flac-resample — intentional sample-rate / bit-depth conversion for FLAC.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-resample}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=flacresample
AU_SUCCESS_COLUMNS='timestamp,flac,status,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

RESAMPLE_RATE="${RESAMPLE_RATE:-}"
RESAMPLE_BITS="${RESAMPLE_BITS:-}"
RESAMPLE_APPLY="${RESAMPLE_APPLY:-0}"
RESAMPLE_ONLY_DOWN="${RESAMPLE_ONLY_DOWN:-1}"

plugin_consume_arg() {
  case "${1:-}" in
    --rate=*)
      RESAMPLE_RATE="${1#--rate=}"; AU_CONSUMED=1
      export AU_CONSUMED RESAMPLE_RATE; return 0 ;;
    --rate)
      [[ -n "${2:-}" ]] || { echo "Error: --rate needs Hz" >&2; return 1; }
      RESAMPLE_RATE=$2; AU_CONSUMED=2
      export AU_CONSUMED RESAMPLE_RATE; return 0 ;;
    --bits=*)
      RESAMPLE_BITS="${1#--bits=}"; AU_CONSUMED=1
      export AU_CONSUMED RESAMPLE_BITS; return 0 ;;
    --bits)
      [[ -n "${2:-}" ]] || { echo "Error: --bits needs 16|24" >&2; return 1; }
      RESAMPLE_BITS=$2; AU_CONSUMED=2
      export AU_CONSUMED RESAMPLE_BITS; return 0 ;;
    --apply)
      RESAMPLE_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED RESAMPLE_APPLY; return 0 ;;
    --allow-upsample)
      RESAMPLE_ONLY_DOWN=0; AU_CONSUMED=1
      export AU_CONSUMED RESAMPLE_ONLY_DOWN; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-resample does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: flac-resample does not support -y (use --apply)" >&2
    return 1
  fi
  if [[ -z "${RESAMPLE_RATE}" && -z "${RESAMPLE_BITS}" ]]; then
    echo "Error: need --rate and/or --bits" >&2
    return 1
  fi
  if [[ -n "${RESAMPLE_RATE}" ]] && ! [[ "${RESAMPLE_RATE}" =~ ^[1-9][0-9]+$ ]]; then
    echo "Error: invalid --rate '${RESAMPLE_RATE}'" >&2
    return 1
  fi
  if [[ -n "${RESAMPLE_BITS}" ]]; then
    case "${RESAMPLE_BITS}" in
      16 | 24) ;;
      *)
        echo "Error: --bits must be 16 or 24" >&2
        return 1
        ;;
    esac
  fi
  export RESAMPLE_RATE RESAMPLE_BITS RESAMPLE_APPLY RESAMPLE_ONLY_DOWN
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac ffmpeg ffprobe flock
}

plugin_banner_extra() {
  local tgt=""
  [[ -n "${RESAMPLE_RATE}" ]] && tgt+="rate=${RESAMPLE_RATE}"
  [[ -n "${RESAMPLE_BITS}" ]] && tgt+="${tgt:+ }bits=${RESAMPLE_BITS}"
  if [[ "${RESAMPLE_APPLY:-0}" -eq 1 ]]; then
    log_always "mode:      apply resample (${tgt})"
  else
    log_always "mode:      report candidates (${tgt}; use --apply)"
  fi
  if [[ "${RESAMPLE_ONLY_DOWN:-1}" -eq 1 ]]; then
    log_always "policy:    down only (skip if already ≤ target)"
  else
    log_always "policy:    allow upsample (--allow-upsample)"
  fi
}

plugin_export_env() {
  export RESAMPLE_RATE RESAMPLE_BITS RESAMPLE_APPLY RESAMPLE_ONLY_DOWN AU_CLEANUP_SKIP
}
