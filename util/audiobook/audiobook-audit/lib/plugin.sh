#!/usr/bin/env bash
# audiobook-audit — QC for .m4b books and multi-file chapter dirs.

AU_TOOL_NAME="${AU_TOOL_NAME:-audiobook-audit}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=abookaudit
AU_SUCCESS_COLUMNS='timestamp,unit,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$(au_audio_exts_for_preset audiobook)
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: audiobook-audit is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: audiobook-audit is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds ffprobe flock
  command -v ffmpeg >/dev/null 2>&1 || true
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  log_always "mode:      audiobook audit (cover, tags, chapters, series)"
}

plugin_export_env() {
  if [[ -z "${AU_ABAUDIT_STATE:-}" ]]; then
    AU_ABAUDIT_STATE=$(audio_utils_mktemp_d "abookaudit.XXXXXX")
    register_tmpdir "$AU_ABAUDIT_STATE"
  fi
  export AU_ABAUDIT_STATE AU_CLEANUP_SKIP AU_SOURCE_EXTS
}
