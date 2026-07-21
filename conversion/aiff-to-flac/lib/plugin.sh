#!/usr/bin/env bash
# aiff-to-flac plugin — shared PCM→FLAC pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-aiff-to-flac}"
AU_SOURCE_EXT=aiff
AU_SOURCE_EXTS="aiff aif"
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=aiff2flac
AU_SUCCESS_COLUMNS='timestamp,aiff,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="cR"
AU_SOURCE_LABEL=aiff

CLEAN_WAV="${CLEAN_WAV:-0}"
RETAG_ONLY="${RETAG_ONLY:-0}"

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

pcm_to_flac_plugin_wire
# shellcheck source=../../../lib/pipeline/pcm_to_flac_hooks.sh
source "$_AU_ROOT/lib/pipeline/pcm_to_flac_hooks.sh"
