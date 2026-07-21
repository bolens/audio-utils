#!/usr/bin/env bash
# Functional: flac-artwork embed/extract, flac-audit, cue-audit,
# dynamics-report.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_mk_cover() { # dest.jpg
  ffmpeg -nostdin -v error -y -f lavfi -i "color=c=red:size=64x64:d=1" \
    -frames:v 1 "$1"
}

_has_picture() {
  metaflac --list --block-type=PICTURE -- "$1" 2>/dev/null | grep -q PICTURE
}

_setup_album() {
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
}

# --- flac-artwork -------------------------------------------------------------

test_artwork_embeds_folder_cover() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  _mk_cover "$T/album/cover.jpg"

  run_tool util/flac/flac-artwork/flac-artwork.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local f
  for f in "$T/album/"*.flac; do
    _has_picture "$f" || fail "no PICTURE block: $f"
    flac -t --totally-silent "$f" || fail "flac -t after embed: $f"
  done
}

test_artwork_embed_skips_existing_without_overwrite() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  _mk_cover "$T/album/cover.jpg"
  run_tool util/flac/flac-artwork/flac-artwork.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0

  local before after
  before=$(sha256sum "$T/album/01 - Track One.flac" | awk '{print $1}')
  run_tool util/flac/flac-artwork/flac-artwork.sh -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "second run rc"
  after=$(sha256sum "$T/album/01 - Track One.flac" | awk '{print $1}')
  assert_eq "$after" "$before" "file must be untouched without -y"
  assert_grep "skipped-existing" "$T/s.csv"
}

test_artwork_extract_writes_cover() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  _mk_cover "$T/album/cover.jpg"
  run_tool util/flac/flac-artwork/flac-artwork.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  rm "$T/album/cover.jpg"

  run_tool util/flac/flac-artwork/flac-artwork.sh -j 1 -x "$T/album"
  assert_eq "$(tool_rc)" 0 "extract rc ($(tool_out | tail -3))"
  assert_file "$T/album/cover.jpg" "extracted cover"
  [[ -s "$T/album/cover.jpg" ]] || fail "extracted cover is empty"
}

test_artwork_no_cover_is_clean_noop() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  run_tool util/flac/flac-artwork/flac-artwork.sh -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "rc"
  assert_grep "no-folder-cover" "$T/s.csv"
  _has_picture "$T/album/01 - Track One.flac" && fail "must not invent art"
  return 0
}

# --- flac-audit -----------------------------------------------------------------

test_flac_audit_clean_album_passes() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  _mk_cover "$T/album/cover.jpg"
  run_tool util/flac/flac-audit/flac-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean album ($(tool_out | tail -3))"
}

test_flac_audit_flags_missing_tags_cover_and_pcm() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  # No cover, strip a core tag, and drop a leftover WAV sibling.
  metaflac --remove-tag=ARTIST "$T/album/01 - Track One.flac"
  : >"$T/album/02 - Track Two.wav"

  run_tool util/flac/flac-audit/flac-audit.sh -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "issues must fail"
  assert_grep "missing-tags:ARTIST" "$T/fails.log"
  assert_grep "no-cover" "$T/fails.log"
  assert_grep "leftover-pcm" "$T/fails.log"
}

test_flac_audit_flags_corrupt_flac() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture flac_corrupt)
  mkdir -p "$T/album"
  cp "$src/corrupt.flac" "$T/album/"
  run_tool util/flac/flac-audit/flac-audit.sh -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1
  assert_grep "flac -t failed" "$T/fails.log"
}

# --- cue-audit ------------------------------------------------------------------

test_cue_audit_clean_album_passes() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture cue_album)
  mkdir -p "$T/album"
  cp "$src/album/CueAlbum.cue" "$src/album/CueAlbum.flac" "$T/album/"
  run_tool util/audit/cue-audit/cue-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean cue ($(tool_out | tail -3))"
}

test_cue_audit_flags_missing_image_and_no_tracks() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture cue_album)
  mkdir -p "$T/album"
  cp "$src/album/CueAlbum.cue" "$T/album/"   # no .flac image

  run_tool util/audit/cue-audit/cue-audit.sh -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "missing image must fail"
  assert_grep "missing-image" "$T/fails.log"

  # CUE with no TRACK entries at all.
  mkdir -p "$T/empty"
  printf 'TITLE "X"\nFILE "img.flac" WAVE\n' >"$T/empty/broken.cue"
  cp "$src/album/CueAlbum.flac" "$T/empty/img.flac"
  run_tool util/audit/cue-audit/cue-audit.sh -j 1 -L "$T/fails2.log" "$T/empty"
  assert_eq "$(tool_rc)" 1 "no tracks must fail"
  assert_grep "no-tracks" "$T/fails2.log"
}

# --- dynamics-report --------------------------------------------------------------

test_dynamics_report_measures_and_writes_summary() {
  require_cmd flac metaflac ffmpeg flock
  _setup_album
  export XDG_STATE_HOME="$T/state"

  run_tool util/audit/dynamics-report/dynamics-report.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local report="$T/state/audio-utils/dynamics-report/dynamics-report.txt"
  assert_file "$report" "summary report"
  assert_grep "EBU R128" "$report"
  assert_grep "01 - Track One" "$report"
  # Success log carries parsed measurements.
  assert_grep "lufs=" "$T/state/audio-utils/dynamics-report/success.csv"
}

run_tests
