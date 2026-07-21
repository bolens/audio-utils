#!/usr/bin/env bash
# audio-dupes — content duplicates across formats (fingerprint default).

AU_TOOL_NAME="${AU_TOOL_NAME:-audio-dupes}"
AU_SOURCE_EXT=flac
AU_SOURCE_EXTS="flac mp3 opus m4a ogg oga wma mpc aac"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=audiodupes
AU_SUCCESS_COLUMNS='timestamp,file,mode,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="M"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

DUPES_DECODE_MD5="${DUPES_DECODE_MD5:-0}"
# Default on for multi-format
DUPES_FINGERPRINT="${DUPES_FINGERPRINT:-1}"

plugin_parse_opt() {
  case "$1" in
    M) DUPES_DECODE_MD5=1; DUPES_FINGERPRINT=0; export DUPES_DECODE_MD5 DUPES_FINGERPRINT; return 0 ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --md5)
      DUPES_DECODE_MD5=1; DUPES_FINGERPRINT=0; AU_CONSUMED=1
      export AU_CONSUMED DUPES_DECODE_MD5 DUPES_FINGERPRINT; return 0 ;;
    --fingerprint)
      DUPES_FINGERPRINT=1; DUPES_DECODE_MD5=0; AU_CONSUMED=1
      export AU_CONSUMED DUPES_FINGERPRINT DUPES_DECODE_MD5; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audio-dupes is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: audio-dupes is read-only; -y is not supported" >&2
    return 1
  fi
  if [[ "${DUPES_FINGERPRINT:-0}" -eq 1 ]] && ! command -v fpcalc >/dev/null 2>&1; then
    echo "Error: fingerprint mode requires fpcalc (chromaprint)" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffmpeg ffprobe flock
  [[ "${DUPES_FINGERPRINT:-0}" -eq 1 ]] && require_cmds fpcalc
}

plugin_banner_extra() {
  if [[ "${DUPES_FINGERPRINT:-0}" -eq 1 ]]; then
    log_always "mode:      chromaprint fingerprint"
  else
    log_always "mode:      decode audio MD5"
  fi
}

plugin_export_env() {
  if [[ -z "${AU_DUPES_STATE:-}" ]]; then
    AU_DUPES_STATE=$(audio_utils_mktemp_d "dupes.XXXXXX")
    register_tmpdir "$AU_DUPES_STATE"
  fi
  export AU_DUPES_STATE DUPES_DECODE_MD5 DUPES_FINGERPRINT AU_CLEANUP_SKIP AU_SOURCE_EXTS
}

plugin_finalize() {
  local index="${AU_DUPES_STATE:-}/index.tsv" groups=0
  [[ -f "$index" ]] || return 0
  groups=$(awk -F'\t' 'NF>=2 {c[$1]++} END {for (k in c) if (c[k]>1) n++; print n+0}' "$index")
  log_always "Duplicate groups: $groups"
}
