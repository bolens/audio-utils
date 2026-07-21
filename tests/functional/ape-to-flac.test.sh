#!/usr/bin/env bash
# Functional: ape-to-flac — decode the vendored Monkey's Audio asset (see
# tests/assets/README.md) to FLAC losslessly. ffmpeg decodes APE natively.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="conversion/ape-to-flac/ape-to-flac.sh"
_ASSET="$AU_REPO_ROOT/tests/assets/tone.ape"

_require_ape_decoder() {
  [[ -f "$_ASSET" ]] || fail "missing vendored asset: $_ASSET"
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$_ASSET" 2>/dev/null \
    | grep -qx ape || skip "ffmpeg lacks an ape decoder"
}

test_ape_converts_losslessly_to_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_ape_decoder
  mkdir -p "$T/album"
  cp "$_ASSET" "$T/album/tone.ape"

  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/tone.flac"
  assert_audio_md5_eq "$T/album/tone.ape" "$T/album/tone.flac"
}

test_ape_skip_existing_and_dry_run() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_ape_decoder
  mkdir -p "$T/album"
  cp "$_ASSET" "$T/album/tone.ape"

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

test_ape_delete_source_contract() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_ape_decoder
  mkdir -p "$T/album"
  cp "$_ASSET" "$T/album/tone.ape"

  run_tool "$_TOOL" -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/tone.flac"
  assert_no_file "$T/album/tone.ape" "-d must remove the source"
}

run_tests
