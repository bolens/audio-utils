#!/usr/bin/env bash
# Functional: flac-replaygain, flac-optimize, flac-strip preserve audio.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_replaygain_tags_album() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  command -v rsgain >/dev/null 2>&1 || command -v loudgain >/dev/null 2>&1 \
    || skip "missing dependency: rsgain or loudgain"
  local src md5_before
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
  md5_before=$(audio_md5 "$T/album/01 - Track One.flac")

  run_tool util/flac/flac-replaygain/flac-replaygain.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "replaygain rc ($(tool_out | tail -3))"

  local tags
  tags=$(metaflac --export-tags-to=- "$T/album/01 - Track One.flac")
  assert_grep "REPLAYGAIN_TRACK_GAIN" "$tags"
  assert_grep "REPLAYGAIN_ALBUM_GAIN" "$tags"
  assert_eq "$(audio_md5 "$T/album/01 - Track One.flac")" "$md5_before" \
    "audio must be untouched"
}

test_optimize_shrinks_and_preserves() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src before after md5_before
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  # Level-0 encode leaves plenty of headroom for -8 to reclaim.
  flac --totally-silent -0 -f -o "$T/album/big.flac" "$src/noise.wav"
  metaflac --set-tag="ARTIST=Keep Me" "$T/album/big.flac"
  before=$(stat -c %s "$T/album/big.flac")
  md5_before=$(audio_md5 "$T/album/big.flac")

  run_tool util/flac/flac-optimize/flac-optimize.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "optimize rc ($(tool_out | tail -3))"
  after=$(stat -c %s "$T/album/big.flac")
  ((after < before)) || fail "not smaller: $before → $after"
  assert_eq "$(audio_md5 "$T/album/big.flac")" "$md5_before" "audio changed"
  assert_grep "^ARTIST=Keep Me$" \
    "$(metaflac --export-tags-to=- "$T/album/big.flac")"
}

test_strip_removes_padding_keeps_tags() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src before after md5_before
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/track.flac"
  metaflac --add-padding=262144 "$T/album/track.flac"
  before=$(stat -c %s "$T/album/track.flac")
  md5_before=$(audio_md5 "$T/album/track.flac")

  run_tool util/flac/flac-strip/flac-strip.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "strip rc ($(tool_out | tail -3))"
  after=$(stat -c %s "$T/album/track.flac")
  ((before - after > 200000)) || fail "padding not removed: $before → $after"
  assert_eq "$(audio_md5 "$T/album/track.flac")" "$md5_before" "audio changed"
  assert_grep "^ARTIST=Test Artist$" \
    "$(metaflac --export-tags-to=- "$T/album/track.flac")"
}

run_tests
