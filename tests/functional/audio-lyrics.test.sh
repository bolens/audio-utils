#!/usr/bin/env bash
# Functional: audio-lyrics report / import / export — entirely offline
# (LYRICS tags and .lrc/.txt sidecars; no network involved).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL="util/audio/audio-lyrics/audio-lyrics.sh"

_lyrics_flac() { # dest
  local src
  src=$(fixture flac_tagged)
  cp "$src/track.flac" "$1"
}

test_report_fails_without_lyrics_anywhere() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/bare.flac"

  run_tool "$_TOOL" -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "no lyrics must fail ($(tool_out | tail -3))"
  assert_grep "bare.flac" "$T/fails.log"
  assert_grep "no lyrics" "$T/fails.log"
}

test_report_passes_with_tag_or_sidecar() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/tagged.flac"
  metaflac --set-tag="LYRICS=la la la" "$T/album/tagged.flac"
  _lyrics_flac "$T/album/sidecar.flac"
  printf '[00:01.00] side lyrics\n' >"$T/album/sidecar.lrc"

  run_tool "$_TOOL" -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_grep "tagged.flac.*tag" "$T/s.csv"
  assert_grep "sidecar.flac.*sidecar" "$T/s.csv"
}

test_import_writes_sidecar_into_tag() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/track.flac"
  printf '[00:01.00] imported line\n' >"$T/album/track.lrc"

  run_tool "$_TOOL" --import -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  metaflac --show-tag=LYRICS "$T/album/track.flac" \
    | grep -q "imported line" || fail "LYRICS tag not written"
}

test_import_respects_existing_tag_without_overwrite() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/track.flac"
  metaflac --set-tag="LYRICS=original words" "$T/album/track.flac"
  printf 'replacement words\n' >"$T/album/track.txt"

  run_tool "$_TOOL" --import -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  metaflac --show-tag=LYRICS "$T/album/track.flac" \
    | grep -q "original words" || fail "existing tag must survive without -y"
  assert_grep "tag-exists" "$T/s.csv"
}

test_export_writes_lrc_from_tag() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/track.flac"
  metaflac --set-tag="LYRICS=exported words" "$T/album/track.flac"

  run_tool "$_TOOL" --export -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.lrc"
  assert_grep "exported words" "$T/album/track.lrc"
}

test_import_then_export_roundtrip() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/track.flac"
  printf '[00:05.00] round trip\n' >"$T/album/track.txt"

  run_tool "$_TOOL" --import -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  rm "$T/album/track.txt"
  run_tool "$_TOOL" --export -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_grep "round trip" "$T/album/track.lrc"
}

test_dry_run_touches_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _lyrics_flac "$T/album/track.flac"
  printf 'words\n' >"$T/album/track.txt"

  run_tool "$_TOOL" --import -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  [[ -z "$(metaflac --show-tag=LYRICS "$T/album/track.flac")" ]] \
    || fail "dry run must not tag"
}

test_rejects_delete_flags() {
  mkdir -p "$T/album"
  run_tool "$_TOOL" -d "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "-d must be rejected"
  assert_grep "does not support -d" "$T/out"
}

run_tests
