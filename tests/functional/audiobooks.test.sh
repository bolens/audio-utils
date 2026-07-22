#!/usr/bin/env bash
# Functional: audiobook chapters / tags / m4b round-trip / audit.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_mk_chapter_flac() { # out title track dur_sec
  local out=$1 title=$2 track=$3 dur=${4:-1}
  local wav="${T}/t${track}.wav"
  ffmpeg -nostdin -v error -y -f lavfi -i "sine=frequency=$((200 + track * 50)):duration=${dur}" \
    -ac 2 -ar 44100 "$wav"
  flac --totally-silent -f -o "$out" "$wav"
  metaflac --set-tag="ARTIST=Test Author" --set-tag="ALBUMARTIST=Test Author" \
    --set-tag="ALBUM=Test Book" --set-tag="TITLE=$title" \
    --set-tag="TRACKNUMBER=$track" --set-tag="GENRE=Audiobook" \
    --set-tag="NARRATOR=Test Narrator" "$out"
  rm -f -- "$wav"
}

_stage_chapters() {
  mkdir -p "$T/book"
  _mk_chapter_flac "$T/book/01 - Chapter One.flac" "Chapter One" 1 1
  _mk_chapter_flac "$T/book/02 - Chapter Two.flac" "Chapter Two" 2 1
  _mk_chapter_flac "$T/book/03 - Chapter Three.flac" "Chapter Three" 3 1
}

test_tracks_to_m4b_and_split_roundtrip() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder aac
  _stage_chapters

  run_tool conversion/tracks-to-m4b/tracks-to-m4b.sh -j 1 "$T/book"
  assert_eq "$(tool_rc)" 0 "tracks-to-m4b rc ($(tool_out | tail -5))"
  assert_file "$T/book.m4b"

  local n
  n=$(ffprobe -v error -show_chapters -of flat=s=_ -- "$T/book.m4b" 2>/dev/null \
    | grep -c '^chapters_chapter_[0-9]*_start_time=' || true)
  assert_eq "$n" 3 "chapter count in m4b"

  run_tool conversion/m4b-to-tracks/m4b-to-tracks.sh -j 1 "$T"
  assert_eq "$(tool_rc)" 0 "m4b-to-tracks rc ($(tool_out | tail -5))"
  assert_file "$T/book/01 - Chapter One.m4a"
  assert_file "$T/book/02 - Chapter Two.m4a"
  assert_file "$T/book/03 - Chapter Three.m4a"
}

test_tracks_to_m4b_opus_codec() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libopus
  _stage_chapters

  run_tool conversion/tracks-to-m4b/tracks-to-m4b.sh -j 1 --codec=opus -Q 64 "$T/book"
  assert_eq "$(tool_rc)" 0 "opus m4b rc ($(tool_out | tail -5))"
  assert_file "$T/book.m4b"
  assert_eq "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 -- "$T/book.m4b")" \
    opus "opus codec in m4b"
}

test_chapters_extract_embed() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder aac
  _stage_chapters
  run_tool conversion/tracks-to-m4b/tracks-to-m4b.sh -j 1 "$T/book"
  assert_eq "$(tool_rc)" 0 "encode for chapters test"

  run_tool util/audiobook/chapters/chapters.sh -j 1 --extract="$T/ffmeta.txt" "$T"
  assert_eq "$(tool_rc)" 0 "extract rc"
  assert_file "$T/ffmeta.txt"
  assert_grep "CHAPTER" "$T/ffmeta.txt"

  # Re-embed (noop rewrite)
  run_tool util/audiobook/chapters/chapters.sh -j 1 --embed="$T/ffmeta.txt" --apply "$T"
  assert_eq "$(tool_rc)" 0 "embed rc ($(tool_out | tail -5))"
}

test_audiobook_tags_apply() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/book"
  _mk_chapter_flac "$T/book/01 - One.flac" "One" 1 1
  # Clear ALBUMARTIST so tool fills from ARTIST; clear genre
  metaflac --remove-tag=ALBUMARTIST --remove-tag=GENRE --set-tag="GENRE=Spoken Word" \
    "$T/book/01 - One.flac"

  run_tool util/audiobook/audiobook-tags/audiobook-tags.sh -j 1 --apply "$T/book"
  assert_eq "$(tool_rc)" 0 "tags apply rc"
  assert_eq "$(metaflac --show-tag=ALBUMARTIST "$T/book/01 - One.flac" | sed 's/.*=//')" \
    "Test Author" "albumartist filled"
  assert_eq "$(metaflac --show-tag=GENRE "$T/book/01 - One.flac" | sed 's/.*=//')" \
    "Audiobook" "genre normalized"
}

test_audiobook_audit_flags_chapterless() {
  require_cmd ffmpeg ffprobe flock
  require_ffmpeg_encoder aac
  mkdir -p "$T/lib"
  # m4b without chapters
  ffmpeg -nostdin -v error -y -f lavfi -i "sine=frequency=440:duration=1" \
    -c:a aac -b:a 64k "$T/lib/bare.m4b"

  run_tool util/audiobook/audiobook-audit/audiobook-audit.sh -j 1 "$T/lib"
  assert_eq "$(tool_rc)" 1 "audit should fail on chapterless m4b"
  assert_grep "no-chapters\|missing-" "$(tool_out)"
}

test_flac_to_aac_default_quality_96() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder aac
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"
  run_tool conversion/flac-to-aac/flac-to-aac.sh -j 1 -S "$T/success.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc"
  assert_grep "96" "$T/success.csv"
  run_tool conversion/flac-to-aac/flac-to-aac.sh -j 1 -y -Q 192 -S "$T/success192.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc 192"
  assert_grep "192" "$T/success192.csv"
}

run_tests
