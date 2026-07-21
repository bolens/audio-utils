#!/usr/bin/env bash
# PCM→FLAC plugin contract hooks — sourced at top level by pcm_to_flac_plugin_wire.
# Drivers invoke these by name.

convert_one() { pcm_to_flac_convert_one "$@"; }
plugin_sibling_ok() { flac_ok "$2"; }
plugin_parse_opt() { pcm_to_flac_plugin_parse_opt "$@"; }
plugin_require_deps() { require_cmds flac ffmpeg ffprobe flock; }
plugin_after_flags() { pcm_to_flac_plugin_after_flags; }
plugin_export_env() { pcm_to_flac_plugin_export_env; }
