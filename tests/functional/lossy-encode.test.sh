#!/usr/bin/env bash
# Functional: flac-to-mp3 / opus / vorbis produce valid, tagged output.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_stage_album() {
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
}

_assert_lossy_outputs() { # ext
  local ext=$1 f n=0
  for f in "$T/album/"*."$ext"; do
    [[ -f "$f" ]] || fail "no .$ext outputs produced"
    ((++n))
    assert_eq "$(ffprobe_tag "$f" artist)" "Test Artist" "artist tag on ${f##*/}"
  done
  assert_eq "$n" 3 "output count (.$ext)"
  # Sources must survive (no -d given).
  assert_file "$T/album/01 - Track One.flac" "source flac kept"
}

test_flac_to_mp3_valid_tagged_output() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  _stage_album
  run_tool conversion/flac-to-mp3/flac-to-mp3.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "flac-to-mp3 rc ($(tool_out | tail -3))"
  _assert_lossy_outputs mp3
}

test_flac_to_opus_valid_tagged_output() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libopus
  _stage_album
  run_tool conversion/flac-to-opus/flac-to-opus.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "flac-to-opus rc ($(tool_out | tail -3))"
  _assert_lossy_outputs opus
}

test_flac_to_vorbis_valid_tagged_output() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libvorbis
  _stage_album
  run_tool conversion/flac-to-vorbis/flac-to-vorbis.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "flac-to-vorbis rc ($(tool_out | tail -3))"
  _assert_lossy_outputs ogg
}

test_flac_to_mp3_dry_run_writes_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  _stage_album
  run_tool conversion/flac-to-mp3/flac-to-mp3.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/01 - Track One.mp3"
}

run_tests
