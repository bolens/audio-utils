#!/usr/bin/env bash
# Functional: per-tool convert-all.sh orchestration — find script discovers
# dirs under AUDIO_UTILS_ROOTS, pipes them to the converter, and the shared
# runner handles empty roots and --version. Exercised via wav-to-flac.
# covers: lib/cli/convert_all.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_CONVERT_ALL="conversion/wav-to-flac/convert-all.sh"

# run_tool closes stdin; convert-all feeds the converter itself, so that is
# exactly the mode we want.
_run_convert_all() {
  AUDIO_UTILS_ROOTS="$T/library" run_tool "$_CONVERT_ALL" "$@"
}

test_convert_all_converts_every_wav_dir_under_roots() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/library/artist/album one" "$T/library/artist/album two" \
    "$T/library/no-audio-here"
  cp "$src/sine.wav" "$T/library/artist/album one/a.wav"
  cp "$src/sine.wav" "$T/library/artist/album two/b.wav"

  _run_convert_all -j 1
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -5))"
  assert_file "$T/library/artist/album one/a.flac"
  assert_file "$T/library/artist/album two/b.flac"
}

test_convert_all_passes_flags_through_to_converter() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/library/album"
  cp "$src/sine.wav" "$T/library/album/a.wav"

  _run_convert_all -n
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/library/album/a.flac" "dry run must not convert"
  assert_grep "album" "$T/out"
}

test_convert_all_reports_empty_roots_cleanly() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/library/empty"

  _run_convert_all
  assert_eq "$(tool_rc)" 0 "empty roots must not fail"
  assert_grep "No WAV directories found" "$T/out"
}

test_convert_all_version_flag() {
  mkdir -p "$T/library"
  _run_convert_all --version
  assert_eq "$(tool_rc)" 0
  assert_grep "convert-all" "$T/out"
}

test_convert_all_fails_without_roots() {
  run_tool "$_CONVERT_ALL"
  assert_eq "$(tool_rc)" 2 "missing roots must exit 2"
  assert_grep "AUDIO_UTILS_ROOTS" "$T/out"
}

run_tests
