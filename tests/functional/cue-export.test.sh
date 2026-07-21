#!/usr/bin/env bash
# Functional: flac-cue-export builds image+CUE; cue-to-flac round-trips it.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

test_export_then_split_roundtrip() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"

  run_tool util/flac/flac-cue-export/flac-cue-export.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "cue-export rc ($(tool_out | tail -3))"

  local cue image
  cue=$(find "$T/album" -name '*.cue' | head -1)
  [[ -n "$cue" ]] || fail "no CUE written"
  image="${cue%.cue}.flac"
  assert_file "$image" "image flac beside CUE"
  assert_eq "$(grep -c 'TRACK [0-9]* AUDIO' "$cue")" 3 "CUE track count"
  flac -t --totally-silent "$image" || fail "image fails flac -t"

  # Round trip: split the exported image in a fresh dir and compare each
  # track's decoded audio to the original.
  mkdir -p "$T/split"
  cp "$cue" "$image" "$T/split/"
  run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/split"
  assert_eq "$(tool_rc)" 0 "cue-to-flac rc ($(tool_out | tail -3))"

  local n
  for n in "01 - Track One" "02 - Track Two" "03 - Track Three"; do
    assert_file "$T/split/$n.flac"
    assert_audio_md5_eq "$T/album/$n.flac" "$T/split/$n.flac"
  done
}

test_export_refuses_to_clobber_foreign_cue() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
  # A pre-existing CUE at the target name (ALBUM tag) must block the export…
  printf 'REM not ours\n' >"$T/album/Test Album.cue"

  run_tool util/flac/flac-cue-export/flac-cue-export.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "export over foreign cue must fail ($(tool_out | tail -3))"
  assert_eq "$(cat "$T/album/Test Album.cue")" "REM not ours" "cue untouched"

  # …and -y overwrites it.
  run_tool util/flac/flac-cue-export/flac-cue-export.sh -j 1 -y "$T/album"
  assert_eq "$(tool_rc)" 0 "-y export rc ($(tool_out | tail -3))"
  assert_grep "TRACK 01 AUDIO" "$T/album/Test Album.cue"
  assert_file "$T/album/Test Album.flac"
}

run_tests
