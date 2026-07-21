#!/usr/bin/env bash
# Functional: audio-artwork embed/extract on lossy files, audio-replaygain
# tagging across FLAC and MP3.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_mk_cover() { # dest.jpg
  ffmpeg -nostdin -v error -y -f lavfi -i "color=c=blue:size=64x64:d=1" \
    -frames:v 1 "$1"
}

_has_video_stream() { # file
  [[ -n "$(ffprobe -v error -select_streams v -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null)" ]]
}

# --- audio-artwork ---------------------------------------------------------------

test_audio_artwork_embeds_cover_into_mp3() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$src/track.mp3" "$T/album/"
  _mk_cover "$T/album/cover.jpg"
  local before
  before=$(audio_md5 "$T/album/track.mp3")

  run_tool util/audio/audio-artwork/audio-artwork.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  _has_video_stream "$T/album/track.mp3" || fail "no attached picture stream"
  assert_eq "$(audio_md5 "$T/album/track.mp3")" "$before" "audio must not be re-encoded"
}

test_audio_artwork_skips_covered_file_without_overwrite() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$src/track.mp3" "$T/album/"
  _mk_cover "$T/album/cover.jpg"
  run_tool util/audio/audio-artwork/audio-artwork.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0

  local before
  before=$(sha256sum "$T/album/track.mp3" | awk '{print $1}')
  run_tool util/audio/audio-artwork/audio-artwork.sh -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(sha256sum "$T/album/track.mp3" | awk '{print $1}')" "$before" \
    "file untouched without -y"
  assert_grep "skipped-existing" "$T/s.csv"
}

test_audio_artwork_extracts_cover_from_mp3() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$src/track.mp3" "$T/album/"
  _mk_cover "$T/album/cover.jpg"
  run_tool util/audio/audio-artwork/audio-artwork.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  rm "$T/album/cover.jpg"

  run_tool util/audio/audio-artwork/audio-artwork.sh -j 1 -x "$T/album"
  assert_eq "$(tool_rc)" 0 "extract rc ($(tool_out | tail -3))"
  assert_file "$T/album/cover.jpg"
  [[ -s "$T/album/cover.jpg" ]] || fail "extracted cover is empty"
}

# --- audio-replaygain --------------------------------------------------------------

_rg_tag() { # file
  ffprobe -v error -show_entries format_tags=REPLAYGAIN_TRACK_GAIN,replaygain_track_gain \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | head -1
}

test_audio_replaygain_tags_flac_and_mp3() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  command -v rsgain >/dev/null 2>&1 || command -v loudgain >/dev/null 2>&1 \
    || skip "no rsgain/loudgain"
  local a b
  a=$(fixture album)
  b=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$a/album/"*.flac "$T/album/"
  cp "$b/track.mp3" "$T/album/"

  run_tool util/audio/audio-replaygain/audio-replaygain.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local f
  for f in "$T/album/01 - Track One.flac" "$T/album/track.mp3"; do
    [[ -n "$(_rg_tag "$f")" ]] || fail "no ReplayGain tag: $f"
  done
}

test_audio_replaygain_dry_run_writes_no_tags() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  command -v rsgain >/dev/null 2>&1 || command -v loudgain >/dev/null 2>&1 \
    || skip "no rsgain/loudgain"
  local a
  a=$(fixture album)
  mkdir -p "$T/album"
  cp "$a/album/"*.flac "$T/album/"

  run_tool util/audio/audio-replaygain/audio-replaygain.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  [[ -z "$(_rg_tag "$T/album/01 - Track One.flac")" ]] \
    || fail "dry run must not tag"
}

run_tests
