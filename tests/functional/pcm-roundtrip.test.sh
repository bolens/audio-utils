#!/usr/bin/env bash
# Functional: wav-to-flac / flac-to-wav round-trip preserves audio bit-for-bit.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_wav_to_flac_roundtrip_md5() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/"

  run_tool conversion/wav-to-flac/wav-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "wav-to-flac rc ($(tool_out | tail -3))"
  assert_file "$T/album/sine.flac"
  assert_audio_md5_eq "$T/album/sine.wav" "$T/album/sine.flac"

  # STREAMINFO MD5 must be set (unverifiable FLACs are a failure class).
  local md5
  md5=$(metaflac --show-md5sum "$T/album/sine.flac")
  [[ "$md5" != "00000000000000000000000000000000" ]] || fail "empty STREAMINFO MD5"
}

test_wav_to_flac_dry_run_writes_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/"

  run_tool conversion/wav-to-flac/wav-to-flac.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/sine.flac" "dry run must not encode"
}

test_flac_to_wav_roundtrip_md5() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool conversion/flac-to-wav/flac-to-wav.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "flac-to-wav rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.wav"
  assert_audio_md5_eq "$T/album/track.flac" "$T/album/track.wav"
}

test_wav_to_flac_success_log_written() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/"
  export XDG_STATE_HOME="$T/state"

  run_tool conversion/wav-to-flac/wav-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc"
  assert_file "$T/state/audio-utils/wav-to-flac/success.csv"
  assert_grep "sine.wav" "$T/state/audio-utils/wav-to-flac/success.csv"
}

run_tests
