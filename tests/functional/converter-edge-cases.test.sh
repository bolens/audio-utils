#!/usr/bin/env bash
# Functional: converter edge cases shared by every pipeline — corrupt input
# must fail with a fail-log row and no output artifact, and filenames with
# unicode, spaces, and shell metacharacters must survive end to end.
# covers: lib/core/log.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_wav_to_flac_garbage_bytes_fail_but_good_file_converts() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/sine.wav" "$T/album/good.wav"
  # Not a RIFF file at all.
  head -c 4096 /dev/urandom >"$T/album/garbage.wav"

  run_tool conversion/wav-to-flac/wav-to-flac.sh \
    -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "run with a bad file must report failure"
  assert_grep "garbage.wav" "$T/fails.log"
  assert_not_grep "good.wav" "$T/fails.log"
  assert_file "$T/album/good.flac" "good sibling must still convert"
}

test_unicode_and_metachar_filenames_survive_conversion() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  local dir="$T/Björk — Vespertine (2001) [FLAC]"
  mkdir -p "$dir"
  local name="01 - Café Nöise 空白 & \$tuff; 'quoted'.wav"
  cp "$src/sine.wav" "$dir/$name"

  run_tool conversion/wav-to-flac/wav-to-flac.sh \
    -j 1 -S "$T/s.csv" "$dir"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$dir/${name%.wav}.flac"
  assert_audio_md5_eq "$dir/$name" "$dir/${name%.wav}.flac"
  assert_grep "Café Nöise" "$T/s.csv"
}

test_unicode_filenames_survive_lossy_encode() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/albüm"
  cp "$src/track.flac" "$T/albüm/Träck ¡uno!.flac"

  run_tool conversion/flac-to-mp3/flac-to-mp3.sh -j 1 "$T/albüm"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/albüm/Träck ¡uno!.mp3"
}

run_tests
