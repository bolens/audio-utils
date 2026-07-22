#!/usr/bin/env bash
# Functional: empty-dirs, audio-compare, flac-resample, multi-disc-layout,
# genre-canonicalize, waveform-export.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_empty_dirs_report_then_remove() {
  require_cmd flock find
  mkdir -p "$T/root/Artist/EmptyAlbum" "$T/root/Artist/KeepAlbum"
  # Non-empty sibling so KeepAlbum is not empty
  : >"$T/root/Artist/KeepAlbum/note.txt"

  run_tool util/library/empty-dirs/empty-dirs.sh -j 1 \
    "$T/root/Artist/EmptyAlbum"
  assert_eq "$(tool_rc)" 1 "empty reported ($(tool_out | tail -3))"
  [[ -d "$T/root/Artist/EmptyAlbum" ]] || fail "empty dir must remain in report mode"

  run_tool util/library/empty-dirs/empty-dirs.sh -j 1 -d \
    "$T/root/Artist/EmptyAlbum"
  assert_eq "$(tool_rc)" 0 "remove rc ($(tool_out | tail -3))"
  assert_no_file "$T/root/Artist/EmptyAlbum"
  [[ -d "$T/root/Artist/KeepAlbum" ]] || fail "non-empty sibling must survive"
}

test_audio_compare_md5_match_and_mismatch() {
  require_cmd flac metaflac ffmpeg ffprobe flock sha256sum
  local src
  src=$(fixture album)
  mkdir -p "$T/main/album" "$T/against/album"
  cp "$src/album/01 - Track One.flac" "$T/main/album/"
  cp "$src/album/01 - Track One.flac" "$T/against/album/"
  export AUDIO_UTILS_ROOTS="$T/main"

  run_tool util/audio/audio-compare/audio-compare.sh -j 1 \
    --against="$T/against" "$T/main/album"
  assert_eq "$(tool_rc)" 0 "match rc ($(tool_out | tail -3))"

  cp "$src/album/02 - Track Two.flac" "$T/against/album/01 - Track One.flac"
  run_tool util/audio/audio-compare/audio-compare.sh -j 1 \
    --against="$T/against" "$T/main/album"
  assert_eq "$(tool_rc)" 1 "mismatch rc ($(tool_out | tail -3))"
}

test_flac_resample_report_and_apply() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local rate
  mkdir -p "$T/album"
  ffmpeg -v error -y -f lavfi -i "sine=frequency=440:duration=0.5" \
    -ar 96000 -c:a flac -sample_fmt s32 "$T/album/hi.flac"
  metaflac --set-tag="TITLE=HiRes" -- "$T/album/hi.flac"

  run_tool util/flac/flac-resample/flac-resample.sh -j 1 \
    --rate=48000 --bits=16 "$T/album"
  assert_eq "$(tool_rc)" 1 "candidate rc ($(tool_out | tail -3))"
  rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate \
    -of csv=p=0 -- "$T/album/hi.flac")
  assert_eq "$rate" 96000 "report must not rewrite"

  run_tool util/flac/flac-resample/flac-resample.sh -j 1 \
    --rate=48000 --bits=16 --apply "$T/album"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate \
    -of csv=p=0 -- "$T/album/hi.flac")
  assert_eq "$rate" 48000 "rate applied"
  assert_eq "$(metaflac --show-tag=TITLE -- "$T/album/hi.flac" | sed 's/^TITLE=//')" \
    "HiRes" "tags preserved"
}

test_multi_disc_layout_report_and_apply() {
  require_cmd flac metaflac flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/01 - Track One.flac" "$T/album/d1.flac"
  cp "$src/album/02 - Track Two.flac" "$T/album/d2.flac"
  metaflac --remove-tag=DISCNUMBER --set-tag="DISCNUMBER=1" \
    --remove-tag=TOTALDISCS --set-tag="TOTALDISCS=2" -- "$T/album/d1.flac"
  metaflac --remove-tag=DISCNUMBER --set-tag="DISCNUMBER=2" \
    --remove-tag=TOTALDISCS --set-tag="TOTALDISCS=2" -- "$T/album/d2.flac"

  run_tool util/library/multi-disc-layout/multi-disc-layout.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "candidate rc ($(tool_out | tail -3))"
  assert_file "$T/album/d1.flac"

  run_tool util/library/multi-disc-layout/multi-disc-layout.sh -j 1 \
    --apply "$T/album"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  assert_file "$T/album/Disc 1/d1.flac"
  assert_file "$T/album/Disc 2/d2.flac"
  assert_no_file "$T/album/d1.flac"
}

test_genre_canonicalize_report_and_apply() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src genre
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/01 - Track One.flac" "$T/album/"
  metaflac --remove-tag=GENRE --set-tag="GENRE=prog rock" \
    -- "$T/album/01 - Track One.flac"

  run_tool util/audio/genre-canonicalize/genre-canonicalize.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "drift rc ($(tool_out | tail -3))"
  genre=$(metaflac --show-tag=GENRE -- "$T/album/01 - Track One.flac" | sed 's/^GENRE=//')
  assert_eq "$genre" "prog rock"

  run_tool util/audio/genre-canonicalize/genre-canonicalize.sh -j 1 \
    --apply "$T/album"
  assert_eq "$(tool_rc)" 0 "apply rc ($(tool_out | tail -3))"
  genre=$(metaflac --show-tag=GENRE -- "$T/album/01 - Track One.flac" | sed 's/^GENRE=//')
  assert_eq "$genre" "Rock"
}

test_waveform_export_writes_png() {
  require_cmd flac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/01 - Track One.flac" "$T/album/"

  run_tool util/audit/waveform-export/waveform-export.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "render rc ($(tool_out | tail -3))"
  assert_file "$T/album/01 - Track One.flac.waveform.png"
}

run_tests
