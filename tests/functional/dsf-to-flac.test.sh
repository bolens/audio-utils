#!/usr/bin/env bash
# Functional: dsf-to-flac — DSD64 → 24-bit PCM FLAC at AUDIO_UTILS_DSD_RATE.
# The DSF fixture is hand-crafted (no DSD encoder exists); ffmpeg decodes it.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="conversion/dsf-to-flac/dsf-to-flac.sh"

_require_dsd_decoder() {
  local src
  src=$(fixture dsf)
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$src/tone.dsf" 2>/dev/null \
    | grep -q '^dsd_' || skip "ffmpeg lacks a DSD decoder"
}

test_dsf_converts_to_24bit_flac_at_default_rate() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_dsd_decoder
  local src
  src=$(fixture dsf)
  mkdir -p "$T/album"
  cp "$src/tone.dsf" "$T/album/"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/tone.flac"
  local rate bits ch
  rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/tone.flac")
  bits=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_raw_sample \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/tone.flac")
  ch=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/tone.flac")
  assert_eq "$rate" "88200" "default AUDIO_UTILS_DSD_RATE"
  assert_eq "$bits" "24" "24-bit PCM"
  assert_eq "$ch" "2" "stereo preserved"
}

test_dsf_honors_dsd_rate_override() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_dsd_decoder
  local src
  src=$(fixture dsf)
  mkdir -p "$T/album"
  cp "$src/tone.dsf" "$T/album/"

  AUDIO_UTILS_DSD_RATE=176400 run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local rate
  rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/tone.flac")
  assert_eq "$rate" "176400" "AUDIO_UTILS_DSD_RATE override"
}

test_dsf_dry_run_and_skip_existing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_dsd_decoder
  local src
  src=$(fixture dsf)
  mkdir -p "$T/album"
  cp "$src/tone.dsf" "$T/album/"

  run_tool "$_TOOL" -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/tone.flac" "dry run must not convert"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  local before
  before=$(sha256sum "$T/album/tone.flac" | awk '{print $1}')
  run_tool "$_TOOL" -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(sha256sum "$T/album/tone.flac" | awk '{print $1}')" "$before" \
    "existing flac must not be rebuilt"
}

run_tests
