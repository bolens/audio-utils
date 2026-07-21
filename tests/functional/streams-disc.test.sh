#!/usr/bin/env bash
# Functional: streams-to-flac (container extraction), disc-inventory
# (VIDEO_TS/BDMV/CUE units), audio-key (INITIALKEY tagging).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

# --- streams-to-flac ------------------------------------------------------------

_mk_mkv() { # dest.mkv n_audio_streams
  local out=$1 n=${2:-1} src
  src=$(fixture wav_sine)
  local -a in=() map=()
  local i
  for ((i = 0; i < n; i++)); do
    in+=(-i "$src/sine.wav")
    map+=(-map "$i:a:0")
  done
  ffmpeg -nostdin -v error -y "${in[@]}" "${map[@]}" -c:a flac "$out"
}

test_streams_extracts_every_audio_stream() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/media"
  _mk_mkv "$T/media/concert.mkv" 2

  run_tool conversion/streams-to-flac/streams-to-flac.sh -j 1 "$T/media"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/media/concert.a0.flac"
  assert_file "$T/media/concert.a1.flac"
  flac -t --totally-silent "$T/media/concert.a0.flac" || fail "a0 not valid flac"
  assert_file "$T/media/concert.mkv" "source kept without -d"
}

test_streams_gates_out_audioless_container() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/media"
  ffmpeg -nostdin -v error -y -f lavfi -i "color=c=red:size=64x64:d=1" \
    -c:v mjpeg "$T/media/silent.mkv"

  # Containers without an audio stream are filtered by the accept hook:
  # clean no-op, not a failure.
  run_tool conversion/streams-to-flac/streams-to-flac.sh -j 1 "$T/media"
  assert_eq "$(tool_rc)" 0 "audioless container is a skip ($(tool_out | tail -3))"
  assert_grep "not accepted" "$T/out"
  assert_eq "$(find "$T/media" -name '*.flac' | wc -l)" 0 "no flac output"
}

test_streams_dry_run_lists_targets() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/media"
  _mk_mkv "$T/media/show.mkv" 1

  run_tool conversion/streams-to-flac/streams-to-flac.sh -n -v "$T/media"
  assert_eq "$(tool_rc)" 0
  assert_grep "show.a0.flac" "$T/out"
  assert_no_file "$T/media/show.a0.flac"
}

# --- disc-inventory --------------------------------------------------------------

test_disc_inventory_counts_units_and_dedupes_video_ts() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture cue_album)

  # VIDEO_TS with two IFOs (must count once), a BDMV, and a CUE dir.
  mkdir -p "$T/lib/Movie/VIDEO_TS" "$T/lib/Concert/BDMV" "$T/lib/Album"
  : >"$T/lib/Movie/VIDEO_TS/VIDEO_TS.IFO"
  : >"$T/lib/Movie/VIDEO_TS/VTS_01_0.IFO"
  : >"$T/lib/Concert/BDMV/index.bdmv"
  cp "$src/album/CueAlbum.cue" "$src/album/CueAlbum.flac" "$T/lib/Album/"

  run_tool util/audit/disc-inventory/disc-inventory.sh -j 1 \
    "$T/lib/Movie" "$T/lib/Concert" "$T/lib/Album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"

  assert_grep "video_ts" "$T/out"
  assert_grep "bdmv" "$T/out"
  assert_grep "cue" "$T/out"
  # Two IFOs in one VIDEO_TS → exactly one video_ts unit line.
  assert_eq "$(grep -c "video_ts.*Movie" "$T/out")" 1 "VIDEO_TS deduped"
}

# --- audio-key --------------------------------------------------------------------

test_audio_key_tags_initialkey_on_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_cmd keyfinder-cli
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool util/audio/audio-key/audio-key.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local key
  key=$(metaflac --show-tag=INITIALKEY "$T/album/track.flac")
  [[ "$key" == INITIALKEY=?* ]] || fail "INITIALKEY not written: '$key'"
}

test_audio_key_skips_already_tagged_without_overwrite() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_cmd keyfinder-cli
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"
  metaflac --set-tag="INITIALKEY=11B" "$T/album/track.flac"

  run_tool util/audio/audio-key/audio-key.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(metaflac --show-tag=INITIALKEY "$T/album/track.flac")" \
    "INITIALKEY=11B" "existing key must survive without -y"
}

run_tests
