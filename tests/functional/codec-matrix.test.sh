#!/usr/bin/env bash
# Functional: remaining codec converters — TTA, WavPack, CAF round-trips,
# WAV↔AIFF remuxes, and the WMA / Speex lossy encoders. Every case is
# encoder-gated so runners with a slim ffmpeg skip rather than fail.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_setup_flac() {
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"
}

_codec() { # file
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

# Convert FLAC → EXT with TO_TOOL, then EXT → FLAC with FROM_TOOL in a
# second dir, asserting decoded audio survives both hops bit-for-bit.
_roundtrip() { # to_tool from_tool ext
  local to=$1 from=$2 ext=$3
  _setup_flac

  run_tool "conversion/$to/$to.sh" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "$to rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.$ext"
  assert_audio_md5_eq "$T/album/track.flac" "$T/album/track.$ext"

  mkdir -p "$T/back"
  cp "$T/album/track.$ext" "$T/back/"
  run_tool "conversion/$from/$from.sh" -j 1 "$T/back"
  assert_eq "$(tool_rc)" 0 "$from rc ($(tool_out | tail -3))"
  assert_file "$T/back/track.flac"
  assert_audio_md5_eq "$T/album/track.flac" "$T/back/track.flac"
}

test_tta_roundtrip() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder tta
  _roundtrip flac-to-tta tta-to-flac tta
}

test_wavpack_roundtrip() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder wavpack
  _roundtrip flac-to-wv wv-to-flac wv
}

test_caf_roundtrip() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _roundtrip flac-to-caf caf-to-flac caf
}

test_wav_to_aiff_and_back() {
  require_cmd ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/"

  run_tool conversion/wav-to-aiff/wav-to-aiff.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "wav-to-aiff rc ($(tool_out | tail -3))"
  assert_file "$T/album/sine.aiff"
  assert_audio_md5_eq "$T/album/sine.wav" "$T/album/sine.aiff"

  mkdir -p "$T/back"
  cp "$T/album/sine.aiff" "$T/back/"
  run_tool conversion/aiff-to-wav/aiff-to-wav.sh -j 1 "$T/back"
  assert_eq "$(tool_rc)" 0 "aiff-to-wav rc ($(tool_out | tail -3))"
  assert_file "$T/back/sine.wav"
  assert_audio_md5_eq "$T/album/sine.wav" "$T/back/sine.wav"
}

test_flac_to_wma_encodes() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder wmav2
  _setup_flac

  run_tool conversion/flac-to-wma/flac-to-wma.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.wma"
  assert_eq "$(_codec "$T/album/track.wma")" wmav2 "output codec"
}

test_flac_to_speex_encodes() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libspeex
  _setup_flac

  run_tool conversion/flac-to-speex/flac-to-speex.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.spx"
  assert_eq "$(_codec "$T/album/track.spx")" speex "output codec"
}

run_tests
