#!/usr/bin/env bash
# Functional: pcm-cleanup, perms-normalize, tree-diff.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_pcm_cleanup_reports_then_deletes_verified_wav() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/"
  flac --totally-silent -f -o "$T/album/sine.flac" "$T/album/sine.wav"

  # Report-only: leftover found, nothing removed.
  run_tool util/library/pcm-cleanup/pcm-cleanup.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "leftover reported ($(tool_out | tail -3))"
  assert_file "$T/album/sine.wav" "report must not delete"

  run_tool util/library/pcm-cleanup/pcm-cleanup.sh -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 0 "delete rc ($(tool_out | tail -3))"
  assert_no_file "$T/album/sine.wav"
  assert_file "$T/album/sine.flac" "flac master must survive"

  run_tool util/library/pcm-cleanup/pcm-cleanup.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean after delete"
}

test_pcm_cleanup_keeps_wav_without_matching_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/"
  # Sibling FLAC holds different audio: MD5 mismatch → must not delete.
  flac --totally-silent -f -o "$T/album/sine.flac" "$src/noise.wav"

  run_tool util/library/pcm-cleanup/pcm-cleanup.sh -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 1 "mismatch must fail ($(tool_out | tail -3))"
  assert_file "$T/album/sine.wav" "mismatched wav must survive"
}

test_perms_normalize_report_then_apply() {
  require_cmd flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
  chmod 600 "$T/album/01 - Track One.flac"

  run_tool util/library/perms-normalize/perms-normalize.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "non-conforming rc ($(tool_out | tail -3))"
  assert_eq "$(stat -c %a "$T/album/01 - Track One.flac")" 600 "report must not chmod"

  run_tool util/library/perms-normalize/perms-normalize.sh -j 1 --apply "$T/album"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  assert_eq "$(stat -c %a "$T/album/01 - Track One.flac")" 644 "mode fixed"

  run_tool util/library/perms-normalize/perms-normalize.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean after apply"
}

_stage_mirror() {
  local src
  src=$(fixture album)
  mkdir -p "$T/main/album" "$T/backup/album"
  cp "$src/album/"*.flac "$T/main/album/"
  cp "$src/album/"*.flac "$T/backup/album/"
}

test_tree_diff_identical_trees_pass() {
  require_cmd flock sha256sum
  _stage_mirror
  export AUDIO_UTILS_ROOTS="$T/main"
  run_tool util/library/tree-diff/tree-diff.sh -j 1 --hash \
    --against="$T/backup" "$T/main/album"
  assert_eq "$(tool_rc)" 0 "identical trees rc ($(tool_out | tail -3))"
}

test_tree_diff_flags_modified_and_missing() {
  require_cmd flock sha256sum
  _stage_mirror
  export AUDIO_UTILS_ROOTS="$T/main"
  printf 'x' >>"$T/backup/album/01 - Track One.flac"
  rm "$T/backup/album/03 - Track Three.flac"

  run_tool util/library/tree-diff/tree-diff.sh -j 1 --hash \
    -L "$T/failures.log" --against="$T/backup" "$T/main/album"
  assert_eq "$(tool_rc)" 1 "diffs rc ($(tool_out | tail -3))"
  assert_grep "01 - Track One" "$T/failures.log"
  assert_grep "03 - Track Three" "$T/failures.log"
}

run_tests
