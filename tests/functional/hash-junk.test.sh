#!/usr/bin/env bash
# Functional: hash-verify write+verify cycle; junk-cleanup report/delete.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_hash_write_then_verify_then_detect_corruption() {
  require_cmd flock sha256sum flac metaflac ffmpeg
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"

  run_tool util/library/hash-verify/hash-verify.sh -j 1 -w "$T/album"
  assert_eq "$(tool_rc)" 0 "write rc ($(tool_out | tail -3))"
  local sidecars
  sidecars=$(find "$T/album" -name '*.sha256' | wc -l)
  assert_eq "$sidecars" 3 "one sidecar per flac"

  run_tool util/library/hash-verify/hash-verify.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "verify rc ($(tool_out | tail -3))"

  # Corrupt one file: verification must now fail.
  printf 'x' >>"$T/album/01 - Track One.flac"
  run_tool util/library/hash-verify/hash-verify.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "corruption detected"
  assert_grep "01 - Track One" "$T/failures.log"
}

test_junk_cleanup_report_then_delete() {
  require_cmd flock flac metaflac ffmpeg
  local src
  src=$(fixture junk_tree)
  mkdir -p "$T/album"
  cp -a "$src/album/." "$T/album/"

  # Report-only: junk found → exit 1, nothing removed.
  run_tool util/library/junk-cleanup/junk-cleanup.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "junk reported ($(tool_out | tail -3))"
  assert_file "$T/album/Thumbs.db" "report must not delete"

  run_tool util/library/junk-cleanup/junk-cleanup.sh -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 0 "delete rc ($(tool_out | tail -3))"
  assert_no_file "$T/album/Thumbs.db"
  assert_no_file "$T/album/.DS_Store"
  assert_no_file "$T/album/._01 - Track One.flac"
  assert_no_file "$T/album/empty.bin"
  assert_file "$T/album/01 - Track One.flac" "audio must survive"

  # Tree is clean now.
  run_tool util/library/junk-cleanup/junk-cleanup.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean after delete"
}

run_tests
