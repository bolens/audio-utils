#!/usr/bin/env bash
# archive-audit — discover and verify preservation packages.

AU_TOOL_NAME="${AU_TOOL_NAME:-archive-audit}"
AU_SOURCE_EXT=json
AU_SOURCE_EXTS=json
AU_DEST_EXT=json
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=archiveaudit
AU_SUCCESS_COLUMNS='timestamp,package,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

ARCHIVE_AUDIT_QUICK="${ARCHIVE_AUDIT_QUICK:-0}"
ARCHIVE_AUDIT_PUBKEY="${ARCHIVE_AUDIT_PUBKEY:-}"
ARCHIVE_AUDIT_SNAPSHOT_DIR="${ARCHIVE_AUDIT_SNAPSHOT_DIR:-}"
ARCHIVE_AUDIT_BASELINE_DIR="${ARCHIVE_AUDIT_BASELINE_DIR:-}"

plugin_consume_arg() {
  case "${1:-}" in
    --quick) ARCHIVE_AUDIT_QUICK=1; AU_CONSUMED=1 ;;
    --public-key) [[ -n "${2:-}" ]] || return 1; ARCHIVE_AUDIT_PUBKEY=$2; AU_CONSUMED=2 ;;
    --snapshot-dir) [[ -n "${2:-}" ]] || return 1; ARCHIVE_AUDIT_SNAPSHOT_DIR=$2; AU_CONSUMED=2 ;;
    --baseline-dir) [[ -n "${2:-}" ]] || return 1; ARCHIVE_AUDIT_BASELINE_DIR=$2; AU_CONSUMED=2 ;;
    *) return 1 ;;
  esac
  export AU_CONSUMED ARCHIVE_AUDIT_QUICK ARCHIVE_AUDIT_PUBKEY \
    ARCHIVE_AUDIT_SNAPSHOT_DIR ARCHIVE_AUDIT_BASELINE_DIR
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 || \
    "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: archive-audit is read-only; -d/-D/-y are not supported" >&2
    return 1
  fi
}

plugin_require_deps() { require_cmds ffmpeg ffprobe flac metaflac flock; }
plugin_accept_source() { [[ "$(basename -- "$1")" == ARCHIVE_COMPLETE.json ]]; }
plugin_banner_extra() { log_always "mode:      preservation package audit"; }
plugin_export_env() {
  AUDIO_UTILS_ARCHIVE_PUBKEY=$ARCHIVE_AUDIT_PUBKEY
  export AUDIO_UTILS_ARCHIVE_PUBKEY ARCHIVE_AUDIT_QUICK \
    ARCHIVE_AUDIT_SNAPSHOT_DIR ARCHIVE_AUDIT_BASELINE_DIR AU_CLEANUP_SKIP
}
