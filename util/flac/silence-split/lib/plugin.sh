#!/usr/bin/env bash
# silence-split — split long FLAC/PCM on silence into numbered track FLACs.

AU_TOOL_NAME="${AU_TOOL_NAME:-silence-split}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=2
AU_WORKDIR_PREFIX=silencesplit
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
# Long images are usually FLAC/WAV/AIFF; keep PCM + flac.
AU_SOURCE_EXTS="flac $AU_AUDIO_EXTS_PCM"
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

SS_SILENCE_SEC="${SS_SILENCE_SEC:-2.0}"
SS_SILENCE_DB="${SS_SILENCE_DB:--50}"
SS_MIN_TRACK="${SS_MIN_TRACK:-10}"
SS_OUTDIR="${SS_OUTDIR:-}"
SS_KEEP_SOURCE="${SS_KEEP_SOURCE:-1}"

plugin_consume_arg() {
  case "${1:-}" in
    --silence-sec=*)
      SS_SILENCE_SEC="${1#--silence-sec=}"; AU_CONSUMED=1
      export AU_CONSUMED SS_SILENCE_SEC; return 0 ;;
    --silence-sec)
      [[ -n "${2:-}" ]] || { echo "Error: --silence-sec needs a value" >&2; return 1; }
      SS_SILENCE_SEC=$2; AU_CONSUMED=2
      export AU_CONSUMED SS_SILENCE_SEC; return 0 ;;
    --silence-db=*)
      SS_SILENCE_DB="${1#--silence-db=}"; AU_CONSUMED=1
      export AU_CONSUMED SS_SILENCE_DB; return 0 ;;
    --silence-db)
      [[ -n "${2:-}" ]] || { echo "Error: --silence-db needs a value" >&2; return 1; }
      SS_SILENCE_DB=$2; AU_CONSUMED=2
      export AU_CONSUMED SS_SILENCE_DB; return 0 ;;
    --min-track=*)
      SS_MIN_TRACK="${1#--min-track=}"; AU_CONSUMED=1
      export AU_CONSUMED SS_MIN_TRACK; return 0 ;;
    --min-track)
      [[ -n "${2:-}" ]] || { echo "Error: --min-track needs a value" >&2; return 1; }
      SS_MIN_TRACK=$2; AU_CONSUMED=2
      export AU_CONSUMED SS_MIN_TRACK; return 0 ;;
    --outdir=*)
      SS_OUTDIR="${1#--outdir=}"; AU_CONSUMED=1
      export AU_CONSUMED SS_OUTDIR; return 0 ;;
    --outdir)
      [[ -n "${2:-}" ]] || { echo "Error: --outdir needs a path" >&2; return 1; }
      SS_OUTDIR=$2; AU_CONSUMED=2
      export AU_CONSUMED SS_OUTDIR; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  # Allow -d to delete source after verified split (optional); reject -D (sibling cleanup N/A).
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: silence-split does not support -D" >&2
    return 1
  fi
  if ! awk -v s="${SS_SILENCE_SEC}" 'BEGIN { exit !(s+0 > 0) }'; then
    echo "Error: --silence-sec must be > 0" >&2
    return 1
  fi
  if ! awk -v s="${SS_MIN_TRACK}" 'BEGIN { exit !(s+0 > 0) }'; then
    echo "Error: --min-track must be > 0" >&2
    return 1
  fi
  export SS_SILENCE_SEC SS_SILENCE_DB SS_MIN_TRACK SS_OUTDIR
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock flac awk
}

plugin_banner_extra() {
  log_always "silence:   ${SS_SILENCE_SEC}s @ ${SS_SILENCE_DB}dB; min-track=${SS_MIN_TRACK}s"
  if [[ -n "${SS_OUTDIR}" ]]; then
    log_always "outdir:    ${SS_OUTDIR}"
  else
    log_always "outdir:    (beside source)"
  fi
}

plugin_export_env() {
  export SS_SILENCE_SEC SS_SILENCE_DB SS_MIN_TRACK SS_OUTDIR AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
