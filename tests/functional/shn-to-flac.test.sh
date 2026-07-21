#!/usr/bin/env bash
# Functional: shn-to-flac — decode the vendored Shorten asset (see
# tests/assets/README.md) to FLAC losslessly. ffmpeg decodes SHN natively.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="conversion/shn-to-flac/shn-to-flac.sh"
_ASSET="$AU_REPO_ROOT/tests/assets/tone.shn"

_require_shn_decoder() {
  [[ -f "$_ASSET" ]] || fail "missing vendored asset: $_ASSET"
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$_ASSET" 2>/dev/null \
    | grep -qx shorten || skip "ffmpeg lacks a shorten decoder"
}

test_shn_converts_losslessly_to_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_shn_decoder
  mkdir -p "$T/album"
  cp "$_ASSET" "$T/album/tone.shn"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/tone.flac"
  assert_audio_md5_eq "$T/album/tone.shn" "$T/album/tone.flac"
}

test_shn_rejects_impostor_extension() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_shn_decoder
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  # A WAV masquerading as .shn must be filtered out by codec probe, not
  # converted by extension alone.
  cp "$src/sine.wav" "$T/album/fake.shn"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "impostor must be gated out, not failed ($(tool_out | tail -3))"
  assert_no_file "$T/album/fake.flac" "impostor must not convert"
}

test_shn_delete_source_contract() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_shn_decoder
  mkdir -p "$T/album"
  cp "$_ASSET" "$T/album/tone.shn"

  run_tool "$_TOOL" -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/tone.flac"
  assert_no_file "$T/album/tone.shn" "-d must remove the source"
}

test_shn_dry_run_converts_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_shn_decoder
  mkdir -p "$T/album"
  cp "$_ASSET" "$T/album/tone.shn"

  run_tool "$_TOOL" -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/tone.flac" "dry run must not convert"
}

run_tests
