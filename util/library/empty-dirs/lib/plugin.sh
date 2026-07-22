#!/usr/bin/env bash
# empty-dirs — report or remove empty album/artist directories.

AU_TOOL_NAME="${AU_TOOL_NAME:-empty-dirs}"
AU_SOURCE_EXT=flac
# No files expected inside empty dirs; discovery lists the dirs themselves.
AU_SOURCE_EXTS="flac"
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=emptydirs
AU_SUCCESS_COLUMNS='timestamp,dir,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1
AU_QUEUE_EMPTY_DIRS=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

EMPTY_DELETE="${EMPTY_DELETE:-0}"

plugin_after_flags() {
  if [[ "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: empty-dirs does not support -D" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: empty-dirs does not support -y" >&2
    return 1
  fi
  if [[ "${DELETE_SOURCE:-0}" -eq 1 ]]; then
    EMPTY_DELETE=1
    DELETE_SOURCE=0
  fi
  export EMPTY_DELETE AU_QUEUE_EMPTY_DIRS
  return 0
}

plugin_require_deps() {
  require_cmds flock find
}

# Only queue directories that are actually empty (leaf).
plugin_accept_source() {
  local p=$1
  [[ -d "$p" ]] || return 1
  # find -empty: no files and no subdirs
  LC_ALL=C find -P "$p" -maxdepth 0 -type d -empty | grep -q .
}

plugin_banner_extra() {
  if [[ "${EMPTY_DELETE:-0}" -eq 1 ]]; then
    log_always "mode:      remove empty directories"
  else
    log_always "mode:      report empty directories (use -d to remove)"
  fi
}

plugin_export_env() {
  export EMPTY_DELETE AU_CLEANUP_SKIP AU_SOURCE_EXTS AU_QUEUE_EMPTY_DIRS
}
