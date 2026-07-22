#!/usr/bin/env bash
# Functional: flac-authenticity flags upsampled/padded fakes, passes real files.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_auth() { # dir
  run_tool util/flac/flac-authenticity/flac-authenticity.sh -j 1 -L "$T/failures.log" "$1"
}

test_flags_upsampled_fake_hires() {
  require_cmd flac metaflac ffmpeg ffprobe flock od awk
  local src
  src=$(fixture flac_hires)
  mkdir -p "$T/fake"
  cp "$src/fake96.flac" "$T/fake/"
  _auth "$T/fake"
  assert_eq "$(tool_rc)" 1 "fake 96k must be flagged ($(tool_out | tail -3))"
  assert_grep "fake96.flac" "$T/failures.log"
}

test_flags_padded_16_in_24() {
  require_cmd flac metaflac ffmpeg ffprobe flock od awk
  local src
  src=$(fixture flac_padded24)
  mkdir -p "$T/padded"
  cp "$src/padded24.flac" "$T/padded/"
  _auth "$T/padded"
  assert_eq "$(tool_rc)" 1 "padded 16→24 must be flagged ($(tool_out | tail -3))"
}

test_passes_genuine_hires() {
  require_cmd flac metaflac ffmpeg ffprobe flock od awk
  local src
  src=$(fixture flac_hires)
  mkdir -p "$T/real"
  cp "$src/real96.flac" "$T/real/"
  _auth "$T/real"
  assert_eq "$(tool_rc)" 0 "genuine 96k must pass ($(tool_out | tail -5))"
}

test_writes_spectrogram_png_with_ffmpeg_backend() {
  require_cmd flac metaflac ffmpeg ffprobe flock od awk
  local src
  src=$(fixture flac_hires)
  mkdir -p "$T/spec"
  cp "$src/fake96.flac" "$T/spec/"

  run_tool util/flac/flac-authenticity/flac-authenticity.sh -j 1 \
    -p --spectrogram-backend=ffmpeg "$T/spec"
  assert_eq "$(tool_rc)" 1 "fake still flagged ($(tool_out | tail -3))"
  assert_file "$T/spec/fake96.ff.png"
}

run_tests
