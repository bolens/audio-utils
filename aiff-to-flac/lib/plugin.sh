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

# shellcheck source=../../lib/plugin_init.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/plugin_init.sh"

pcm_to_flac_plugin_wire
