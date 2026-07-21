#!/usr/bin/env bash
# Lossy plugin contract hooks — sourced at top level by lossy_plugin_wire.
# Drivers invoke these by name.

convert_one() { lossy_convert_one "$@"; }
plugin_sibling_ok() { lossy_ok "$2"; }
plugin_consume_arg() { lossy_plugin_consume_arg "$@"; }
plugin_parse_opt() { lossy_plugin_parse_opt "$@"; }
plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe flock || return 1
  require_ffmpeg_encoder "$LOSSY_FFMPEG_ENCODER"
}
plugin_after_flags() { lossy_plugin_after_flags; }
plugin_banner_extra() { lossy_plugin_banner; }
plugin_export_env() { lossy_plugin_export_env; }
