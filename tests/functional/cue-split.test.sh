#!/usr/bin/env bash
# Functional: cue-to-flac splits a CUE+image album into per-track FLACs.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_stage_cue_album() {
  local src
  src=$(fixture cue_album)
  mkdir -p "$T/album"
  cp "$src/album/CueAlbum.flac" "$src/album/CueAlbum.cue" "$T/album/"
}

test_cue_split_track_count_and_tags() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_cue_album

  run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "cue-to-flac rc ($(tool_out | tail -3))"
  assert_file "$T/album/01 - Part One.flac"
  assert_file "$T/album/02 - Part Two.flac"
  assert_file "$T/album/03 - Part Three.flac"

  # Each track decodes cleanly and carries the CUE title.
  flac -t --totally-silent "$T/album/01 - Part One.flac" || fail "track 1 fails flac -t"
  assert_eq "$(ffprobe_tag "$T/album/02 - Part Two.flac" title)" "Part Two" "track 2 title"

  # 3 × 2s tracks: each split is ~2 seconds long.
  local dur
  dur=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/01 - Part One.flac")
  awk -v d="$dur" 'BEGIN { exit !(d > 1.8 && d < 2.2) }' \
    || fail "track 1 duration $dur not ~2s"
}

test_cue_split_dry_run_writes_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_cue_album
  run_tool conversion/cue-to-flac/cue-to-flac.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/01 - Part One.flac"
}

run_tests
