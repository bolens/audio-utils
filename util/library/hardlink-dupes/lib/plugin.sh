#!/usr/bin/env bash
# hardlink-dupes — reclaim space by hardlinking content-identical FLACs.

AU_TOOL_NAME="${AU_TOOL_NAME:-hardlink-dupes}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=hardlinkdupes
AU_SUCCESS_COLUMNS='timestamp,flac,status,audio_md5,file_sha256,codec,bytes,samples,notes'
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

HL_APPLY="${HL_APPLY:-0}"
HL_DECODE_MD5="${HL_DECODE_MD5:-0}"
HL_CROSS_FS="${HL_CROSS_FS:-0}"

plugin_parse_opt() {
  case "$1" in
    M)
      HL_DECODE_MD5=1
      export HL_DECODE_MD5
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --apply)
      HL_APPLY=1; AU_CONSUMED=1
      export AU_CONSUMED HL_APPLY; return 0 ;;
    --md5)
      HL_DECODE_MD5=1; AU_CONSUMED=1
      export AU_CONSUMED HL_DECODE_MD5; return 0 ;;
    --cross-fs)
      HL_CROSS_FS=1; AU_CONSUMED=1
      export AU_CONSUMED HL_CROSS_FS; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: hardlink-dupes does not support -d/-D (use --apply to hardlink)" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: hardlink-dupes does not support -y (use --apply)" >&2
    return 1
  fi
  export HL_APPLY HL_DECODE_MD5 HL_CROSS_FS
  return 0
}

plugin_require_deps() {
  if [[ "${HL_DECODE_MD5:-0}" -eq 1 ]]; then
    require_cmds flac ffmpeg ffprobe flock metaflac ln
  else
    require_cmds flac flock metaflac ln
  fi
}

plugin_banner_extra() {
  local mode="report hardlink candidates"
  [[ "${HL_APPLY:-0}" -eq 1 ]] && mode="apply hardlinks"
  if [[ "${HL_DECODE_MD5:-0}" -eq 1 ]]; then
    mode+="; decode-md5"
  else
    mode+="; streaminfo-md5"
  fi
  [[ "${HL_CROSS_FS:-0}" -eq 1 ]] && mode+="; cross-fs (best-effort)"
  log_always "mode:      $mode"
}

plugin_export_env() {
  if [[ -z "${AU_HL_STATE:-}" ]]; then
    AU_HL_STATE=$(audio_utils_mktemp_d "hardlink.XXXXXX")
    register_tmpdir "$AU_HL_STATE"
  fi
  : >"${AU_HL_STATE}/linked.tsv"
  export AU_HL_STATE HL_APPLY HL_DECODE_MD5 HL_CROSS_FS AU_CLEANUP_SKIP
}

plugin_finalize() {
  local index="${AU_HL_STATE:-}/index.tsv"
  local groups=0 linked=0
  [[ -f "$index" ]] || return 0
  groups=$(awk -F'\t' 'NF>=2 {c[$1]++} END {for (k in c) if (c[k]>1) n++; print n+0}' "$index")
  linked=$(wc -l <"${AU_HL_STATE}/linked.tsv" 2>/dev/null | tr -d ' ' || echo 0)
  log_always "Duplicate groups: $groups; hardlinked this run: ${linked:-0}"
}
