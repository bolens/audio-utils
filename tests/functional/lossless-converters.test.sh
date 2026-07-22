#!/usr/bin/env bash
# Functional: aiff/alac lossless round-trips, flac-to-aac, lossy-to-flac
# rescue decode, and the -d / -D source-deletion contract.
# covers: lib/media/lossless.sh lib/core/delete.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_mk_aiff() { # dest.aiff
  local src
  src=$(fixture wav_sine)
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a pcm_s16be \
    -metadata title="Aiff Title" -metadata artist="Test Artist" "$1"
}

_mk_alac() { # dest.m4a
  local src
  src=$(fixture wav_sine)
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a alac \
    -metadata title="Alac Title" -metadata artist="Test Artist" "$1"
}

_codec() { # file
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

# MD5 of decoded audio forced to s24: MP3 decodes to float and lossy-to-flac
# stores it as 24-bit PCM, so comparing native sample formats (float vs s24)
# can never match; force both sides through the same float→s24 conversion.
_md5_s24() { # file
  ffmpeg -nostdin -v error -i "$1" -map 0:a:0 -c:a pcm_s24le -f md5 - 2>/dev/null \
    | sed 's/^MD5=//'
}

test_aiff_to_flac_roundtrip_md5() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _mk_aiff "$T/album/song.aiff"

  run_tool conversion/aiff-to-flac/aiff-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/song.flac"
  assert_audio_md5_eq "$T/album/song.aiff" "$T/album/song.flac"
}

test_flac_to_aiff_roundtrip_md5() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool conversion/flac-to-aiff/flac-to-aiff.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.aiff"
  assert_audio_md5_eq "$T/album/track.flac" "$T/album/track.aiff"
}

test_alac_to_flac_roundtrip_md5() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder alac
  mkdir -p "$T/album"
  _mk_alac "$T/album/song.m4a"

  run_tool conversion/alac-to-flac/alac-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/song.flac"
  assert_audio_md5_eq "$T/album/song.m4a" "$T/album/song.flac"
}

test_flac_to_alac_roundtrip_md5() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder alac
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool conversion/flac-to-alac/flac-to-alac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.m4a"
  assert_eq "$(_codec "$T/album/track.m4a")" alac "output codec"
  assert_audio_md5_eq "$T/album/track.flac" "$T/album/track.m4a"
}

test_flac_to_aac_produces_tagged_m4a() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder aac
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool conversion/flac-to-aac/flac-to-aac.sh -j 1 -S "$T/success.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.m4a"
  assert_eq "$(_codec "$T/album/track.m4a")" aac "output codec"
  assert_eq "$(ffprobe_tag "$T/album/track.m4a" title)" "Test Title" "tag carried"
  # Success log has a quality column with the encode setting.
  assert_grep "quality" "$T/success.csv"
  assert_grep "96" "$T/success.csv"
}

test_lossy_to_flac_decodes_mp3() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$src/track.mp3" "$T/album/"

  run_tool conversion/lossy-to-flac/lossy-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.flac"
  assert_eq "$(_md5_s24 "$T/album/track.flac")" "$(_md5_s24 "$T/album/track.mp3")" \
    "decoded audio must match"
}

test_lossy_to_flac_skips_alac_m4a() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder alac
  mkdir -p "$T/album"
  _mk_alac "$T/album/lossless.m4a"

  run_tool conversion/lossy-to-flac/lossy-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_no_file "$T/album/lossless.flac" "ALAC m4a must be codec-gated out"
  assert_file "$T/album/lossless.m4a" "source untouched"
}

test_delete_source_after_verified_conversion() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _mk_aiff "$T/album/song.aiff"

  run_tool conversion/aiff-to-flac/aiff-to-flac.sh -j 1 -d "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/song.flac"
  assert_no_file "$T/album/song.aiff" "-d must remove the source"
}

test_cleanup_mode_deletes_source_only_with_valid_sibling() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  _mk_aiff "$T/album/converted.aiff"
  _mk_aiff "$T/album/orphan.aiff"

  # Convert one file, then run -D cleanup over the dir.
  run_tool conversion/aiff-to-flac/aiff-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  rm -f "$T/album/orphan.flac"

  run_tool conversion/aiff-to-flac/aiff-to-flac.sh -j 1 -D "$T/album"
  assert_eq "$(tool_rc)" 0 "cleanup rc ($(tool_out | tail -3))"
  assert_no_file "$T/album/converted.aiff" "source with valid flac removed"
  assert_file "$T/album/orphan.aiff" "orphan without flac kept"
}

run_tests
