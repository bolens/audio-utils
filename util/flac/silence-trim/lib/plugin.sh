#!/usr/bin/env bash
# silence-trim — trim leading/trailing silence (report / --apply).

AU_TOOL_NAME="${AU_TOOL_NAME:-silence-trim}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=silencetrim
AU_SUCCESS_COLUMNS='timestamp,src,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
# Rip cleanup peers silence-split: FLAC + PCM masters.
AU_SOURCE_EXTS="flac $AU_AUDIO_EXTS_PCM"
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

ST_SILENCE_SEC="${ST_SILENCE_SEC:-1.0}"
ST_SILENCE_DB="${ST_SILENCE_DB:--50}"
ST_PAD_SEC="${ST_PAD_SEC:-0.05}"
ST_MIN_KEEP="${ST_MIN_KEEP:-1.0}"
ST_APPLY="${ST_APPLY:-0}"
ST_LEAD="${ST_LEAD:-1}"
ST_TRAIL="${ST_TRAIL:-1}"

plugin_consume_arg() {
  case "${1:-}" in
    --silence-sec=*)
      ST_SILENCE_SEC="${1#--silence-sec=}"; AU_CONSUMED=1
      export AU_CONSUMED ST_SILENCE_SEC; return 0 ;;
    --silence-sec)
      [[ -n "${2:-}" ]] || { echo "Error: --silence-sec needs a value" >&2; return 1; }
      ST_SILENCE_SEC=$2; AU_CONSUMED=2
      export AU_CONSUMED ST_SILENCE_SEC; return 0 ;;
    --silence-db=*)
      ST_SILENCE_DB="${1#--silence-db=}"; AU_CONSUMED=1
      export AU_CONSUMED ST_SILENCE_DB; return 0 ;;
    --silence-db)
      [[ -n "${2:-}" ]] || { echo "Error: --silence-db needs a value" >&2; return 1; }
      ST_SILENCE_DB=$2; AU_CONSUMED=2
      export AU_CONSUMED ST_SILENCE_DB; return 0 ;;
    --pad-sec=*)
      ST_PAD_SEC="${1#--pad-sec=}"; AU_CONSUMED=1
      export AU_CONSUMED ST_PAD_SEC; return 0 ;;
    --pad-sec)
      [[ -n "${2:-}" ]] || { echo "Error: --pad-sec needs a value" >&2; return 1; }
      ST_PAD_SEC=$2; AU_CONSUMED=2
      export AU_CONSUMED ST_PAD_SEC; return 0 ;;
    --min-keep=*)
      ST_MIN_KEEP="${1#--min-keep=}"; AU_CONSUMED=1
      export AU_CONSUMED ST_MIN_KEEP; return 0 ;;
    --min-keep)
      [[ -n "${2:-}" ]] || { echo "Error: --min-keep needs a value" >&2; return 1; }
      ST_MIN_KEEP=$2; AU_CONSUMED=2
      export AU_CONSUMED ST_MIN_KEEP; return 0 ;;
    --apply)
      ST_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED ST_APPLY; return 0 ;;
    --lead-only)
      ST_LEAD=1; ST_TRAIL=0; AU_CONSUMED=1
      export AU_CONSUMED ST_LEAD ST_TRAIL; return 0 ;;
    --trail-only)
      ST_LEAD=0; ST_TRAIL=1; AU_CONSUMED=1
      export AU_CONSUMED ST_LEAD ST_TRAIL; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: silence-trim does not support -d/-D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: silence-trim does not support -y (use --apply)" >&2
    return 1
  fi
  if ! awk -v s="${ST_SILENCE_SEC}" 'BEGIN { exit !(s+0 > 0) }'; then
    echo "Error: --silence-sec must be > 0" >&2
    return 1
  fi
  if ! awk -v s="${ST_PAD_SEC}" 'BEGIN { exit !(s+0 >= 0) }'; then
    echo "Error: --pad-sec must be >= 0" >&2
    return 1
  fi
  if ! awk -v s="${ST_MIN_KEEP}" 'BEGIN { exit !(s+0 > 0) }'; then
    echo "Error: --min-keep must be > 0" >&2
    return 1
  fi
  export ST_SILENCE_SEC ST_SILENCE_DB ST_PAD_SEC ST_MIN_KEEP ST_APPLY ST_LEAD ST_TRAIL
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock flac metaflac awk
}

plugin_banner_extra() {
  local scope="lead+trail"
  if [[ "${ST_LEAD}" -eq 1 && "${ST_TRAIL}" -eq 0 ]]; then
    scope="lead-only"
  elif [[ "${ST_LEAD}" -eq 0 && "${ST_TRAIL}" -eq 1 ]]; then
    scope="trail-only"
  fi
  log_always "silence:   ${ST_SILENCE_SEC}s @ ${ST_SILENCE_DB}dB; pad=${ST_PAD_SEC}s; min-keep=${ST_MIN_KEEP}s (${scope})"
  if [[ "${ST_APPLY:-0}" -eq 1 ]]; then
    log_always "mode:      apply trim"
  else
    log_always "mode:      report candidates (use --apply)"
  fi
}

plugin_export_env() {
  export ST_SILENCE_SEC ST_SILENCE_DB ST_PAD_SEC ST_MIN_KEEP ST_APPLY ST_LEAD ST_TRAIL \
    AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
