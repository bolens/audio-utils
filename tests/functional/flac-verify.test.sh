#!/usr/bin/env bash
# Functional: flac-verify passes clean albums and flags corrupt files.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_verify_clean_album_passes() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"

  run_tool util/flac/flac-verify/flac-verify.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean album rc ($(tool_out | tail -3))"
}

test_verify_flags_corrupt_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture flac_corrupt)
  mkdir -p "$T/album"
  cp "$src/corrupt.flac" "$T/album/"

  run_tool util/flac/flac-verify/flac-verify.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "corrupt album rc ($(tool_out | tail -3))"
  assert_file "$T/failures.log"
  assert_grep "corrupt.flac" "$T/failures.log"
}

test_verify_is_read_only() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"

  run_tool util/flac/flac-verify/flac-verify.sh -d "$T/album"
  assert_eq "$(tool_rc)" 2 "-d must be rejected"
}

run_tests
