#!/usr/bin/env bash
# wav-to-flac plugin — shared PCM→FLAC pipeline.

AU_TOOL_NAME="${AU_TOOL_NAME:-wav-to-flac}"
AU_SOURCE_EXT=wav
AU_DEST_EXT=flac
AU_DISK_FACTOR=3
AU_WORKDIR_PREFIX=wav2flac
AU_SUCCESS_COLUMNS='timestamp,wav,flac,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="cR"
AU_SOURCE_LABEL=wav

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
