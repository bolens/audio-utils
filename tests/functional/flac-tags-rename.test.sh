#!/usr/bin/env bash
# Functional: flac-tags normalization and flac-rename, dry-run vs apply.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_stage_messy_flac() {
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/track.flac"
  # Fixture ships TRACKNUMBER=1 (unpadded); add junk that must be stripped.
  metaflac --set-tag="ENCODER=TestEnc 1.0" --set-tag="ITUNNORM=deadbeef" \
    "$T/album/track.flac"
}

_tags_of() { metaflac --export-tags-to=- "$1"; }

test_flac_tags_dry_run_changes_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_messy_flac
  local before
  before=$(_tags_of "$T/album/track.flac")

  run_tool util/flac/flac-tags/flac-tags.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_eq "$(_tags_of "$T/album/track.flac")" "$before" "tags must be untouched"
}

test_flac_tags_apply_normalizes() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_messy_flac

  run_tool util/flac/flac-tags/flac-tags.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  local tags
  tags=$(_tags_of "$T/album/track.flac")
  assert_grep "^TRACKNUMBER=01$" "$tags"
  assert_not_grep "ENCODER" "$tags"
  assert_not_grep "ITUNNORM" "$tags"
  assert_grep "^ARTIST=Test Artist$" "$tags"
  flac -t --totally-silent "$T/album/track.flac" || fail "flac -t after rewrite"
}

test_flac_rename_dry_run_then_apply() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/badly named.flac"

  run_tool util/flac/flac-rename/flac-rename.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_file "$T/album/badly named.flac" "dry run must not rename"
  assert_grep "would rename" "$T/out"

  run_tool util/flac/flac-rename/flac-rename.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  assert_file "$T/album/01 - Test Title.flac"
  assert_no_file "$T/album/badly named.flac"
}

test_flac_rename_already_named_is_noop() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/01 - Test Title.flac"

  run_tool util/flac/flac-rename/flac-rename.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "noop rc"
  assert_file "$T/album/01 - Test Title.flac"
}

run_tests
