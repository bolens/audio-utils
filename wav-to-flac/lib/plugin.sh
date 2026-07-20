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

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

pcm_to_flac_plugin_wire
