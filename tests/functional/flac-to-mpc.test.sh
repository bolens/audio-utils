#!/usr/bin/env bash
# Functional: flac-to-mpc — Musepack encode via mpcenc with duration verify
# and APE tag carry-over. Gated on mpcenc (musepack-tools).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="conversion/flac-to-mpc/flac-to-mpc.sh"

_require_mpc() {
  if ! command -v mpcenc >/dev/null 2>&1 || ! command -v mpcdec >/dev/null 2>&1; then
    skip "no mpcenc/mpcdec (musepack-tools)"
  fi
}

_mpc_tag() { # file key
  ffprobe -v error -show_entries format_tags="$2" \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | head -1
}

test_mpc_encode_produces_valid_tagged_output() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mpc
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.mpc"
  local codec
  codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/track.mpc")
  [[ "$codec" == musepack* ]] || fail "unexpected codec: $codec"
  assert_eq "$(_mpc_tag "$T/album/track.mpc" title)" "Test Title" \
    "APE tags must carry over"
}

test_mpc_duration_matches_source() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mpc
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  # ffprobe misreports SV8 declared duration; measure by real decode.
  mpcdec "$T/album/track.mpc" "$T/dec.wav" >/dev/null 2>&1 \
    || fail "mpcdec decode failed"
  local d1 d2
  d1=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/track.flac")
  d2=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$T/dec.wav")
  awk -v a="$d1" -v b="$d2" 'BEGIN { d = a - b; if (d < 0) d = -d; exit !(d <= 0.06) }' \
    || fail "duration drift: flac=$d1 mpc-decoded=$d2"
}

test_mpc_quality_profile_flag() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mpc
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool "$_TOOL" -j 1 -Q radio -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_grep "radio" "$T/s.csv"
}

test_mpc_rejects_bad_quality() {
  _require_mpc
  mkdir -p "$T/album"
  run_tool "$_TOOL" -Q bogus "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "bogus quality must be rejected"
}

test_mpc_skips_existing_and_dry_run() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_mpc
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool "$_TOOL" -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/track.mpc" "dry run must not encode"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  local before
  before=$(sha256sum "$T/album/track.mpc" | awk '{print $1}')
  run_tool "$_TOOL" -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(sha256sum "$T/album/track.mpc" | awk '{print $1}')" "$before" \
    "existing mpc must not be re-encoded"
  assert_grep "skipped-existing" "$T/s.csv"
}

run_tests
