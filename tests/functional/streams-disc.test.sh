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

test_bluray_plain_media_preserves_newline_filename() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local name=$'Concert\nLive.mkv'
  mkdir -p "$T/bluray-media"
  _mk_mkv "$T/bluray-media/$name" 1

  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T/bluray-media"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/bluray-media/flac/${name}.a0.flac"
  flac -t --totally-silent \
    "$T/bluray-media/flac/${name}.a0.flac" || fail "invalid FLAC"
}

test_bluray_mirrors_subdirs_and_avoids_basename_collisions() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/media/one" "$T/media/two"
  _mk_mkv "$T/media/one/title.mkv" 1
  _mk_mkv "$T/media/two/title.mkv" 1

  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T/media"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -5))"
  assert_file "$T/media/flac/one/title.mkv.a0.flac"
  assert_file "$T/media/flac/two/title.mkv.a0.flac"
  assert_eq "$(metaflac --show-bps "$T/media/flac/one/title.mkv.a0.flac")" 16
}

test_bluray_preserves_16_bit_depth_and_stream_provenance() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/media"
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -map 0:a:0 \
    -metadata:s:a:0 language=eng -metadata:s:a:0 title='Main Program' \
    -c:a pcm_s16le "$T/media/program.mkv"

  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T/media"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -5))"
  local out="$T/media/flac/program.mkv.a0.flac"
  assert_file "$out"
  assert_eq "$(metaflac --show-bps "$out")" 16
  assert_grep '^SOURCE_CODEC=pcm_s16le$' "$(metaflac --export-tags-to=- "$out")"
  assert_grep '^SOURCE_LANGUAGE=eng$' "$(metaflac --export-tags-to=- "$out")"
  assert_grep '^SOURCE_TITLE=Main Program$' "$(metaflac --export-tags-to=- "$out")"
  assert_grep '^SOURCE_AUDIO_MD5=[0-9a-f]\{32\}$' "$(metaflac --export-tags-to=- "$out")"
  assert_grep '^SOURCE_STREAM=0$' "$(metaflac --export-tags-to=- "$out")"
}

test_bluray_marks_lossy_sources() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder ac3
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/media"
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a ac3 "$T/media/lossy.mkv"

  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T/media"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -5))"
  local tags
  tags=$(metaflac --export-tags-to=- "$T/media/flac/lossy.mkv.a0.flac")
  assert_grep '^SOURCE_CODEC=ac3$' "$tags"
  assert_grep '^LOSSY_SOURCE=1$' "$tags"
  assert_grep 'lossy source codec ac3' "$T/out"
}

test_bluray_dry_run_lists_exact_outputs_and_rejects_silent_media() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/media/sub"
  _mk_mkv "$T/media/sub/show.mkv" 2

  run_tool conversion/bluray-to-flac/bluray-to-flac.sh -n "$T/media"
  assert_eq "$(tool_rc)" 0
  assert_grep 'flac/sub/show.mkv.a0.flac' "$T/out"
  assert_grep 'flac/sub/show.mkv.a1.flac' "$T/out"
  assert_no_file "$T/media/flac/sub/show.mkv.a0.flac"

  ffmpeg -nostdin -v error -y -f lavfi -i 'color=c=black:s=16x16:d=1' \
    -c:v ffv1 "$T/silent.mkv"
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh -n "$T/silent.mkv"
  assert_eq "$(tool_rc)" 1
  assert_grep 'would fail (no readable audio)' "$T/out"
}

test_bluray_accepts_ts_inside_media_directory() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/media"
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a mp2 -f mpegts "$T/media/show.ts"
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T/media"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -5))"
  assert_file "$T/media/flac/show.ts.a0.flac"
}

test_bluray_rejects_stale_output_unless_overwrite_requested() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src fixture_dir old_sha new_sha
  fixture_dir=$(fixture wav_sine)
  mkdir -p "$T/media"
  src="$T/media/show.mkv"
  ffmpeg -nostdin -v error -y -i "$fixture_dir/sine.wav" -c:a pcm_s16le "$src"
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$src"
  assert_eq "$(tool_rc)" 0
  old_sha=$(metaflac --show-tag=SOURCE_AUDIO_MD5 "$T/media/show.mkv.a0.flac")

  ffmpeg -nostdin -v error -y -f lavfi -i 'sine=frequency=880:duration=1' \
    -c:a pcm_s16le "$src"
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$src"
  assert_eq "$(tool_rc)" 1
  assert_grep 'existing output does not match source audio; use -y' "$T/out"
  assert_eq "$(metaflac --show-tag=SOURCE_AUDIO_MD5 "$T/media/show.mkv.a0.flac")" "$old_sha"

  run_tool conversion/bluray-to-flac/bluray-to-flac.sh -y "$src"
  assert_eq "$(tool_rc)" 0
  new_sha=$(metaflac --show-tag=SOURCE_AUDIO_MD5 "$T/media/show.mkv.a0.flac")
  [[ "$new_sha" != "$old_sha" ]] || fail "overwrite kept stale source identity"
}

test_bluray_rejects_invalid_title_controls() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh --title nope "$T"
  assert_eq "$(tool_rc)" 2
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh --minlength -1 "$T"
  assert_eq "$(tool_rc)" 2
  AUDIO_UTILS_BD_TITLE=bad run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T"
  assert_eq "$(tool_rc)" 2
  AUDIO_UTILS_BD_MIN_LENGTH=bad run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T"
  assert_eq "$(tool_rc)" 2
  AUDIO_UTILS_BD_DISC_ID='../bad' run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$T"
  assert_eq "$(tool_rc)" 2
}

test_bluray_accepts_metadata_only_source_remux() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local fixture_dir src tmp old_md5
  fixture_dir=$(fixture wav_sine)
  mkdir -p "$T/media"
  src="$T/media/show.mkv"
  tmp="$T/media/remux.mkv"
  ffmpeg -nostdin -v error -y -i "$fixture_dir/sine.wav" -c:a flac "$src"
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$src"
  assert_eq "$(tool_rc)" 0
  old_md5=$(metaflac --show-tag=SOURCE_AUDIO_MD5 "$T/media/show.mkv.a0.flac")

  ffmpeg -nostdin -v error -y -i "$src" -map 0:a:0 -c:a copy \
    -metadata title='Metadata changed' "$tmp"
  mv -f -- "$tmp" "$src"
  run_tool conversion/bluray-to-flac/bluray-to-flac.sh "$src"
  assert_eq "$(tool_rc)" 0 "metadata-only remux should retain identical audio"
  assert_grep 'skip (source-bound flac ok)' "$T/out"
  assert_eq "$(metaflac --show-tag=SOURCE_AUDIO_MD5 "$T/media/show.mkv.a0.flac")" "$old_md5"
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

_require_runnable_keyfinder() {
  local rc=0
  require_cmd keyfinder-cli
  keyfinder-cli --help >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 126 && "$rc" -ne 127 ]] || skip "keyfinder-cli is not runnable"
}

test_audio_key_tags_initialkey_on_flac() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_runnable_keyfinder
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
  _require_runnable_keyfinder
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

test_audio_key_rejects_broken_backend_preflight() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/bin" "$T/empty"
  printf '#!/usr/bin/env bash\nexit 127\n' >"$T/bin/keyfinder-cli"
  chmod +x "$T/bin/keyfinder-cli"

  PATH="$T/bin:$PATH" run_tool util/audio/audio-key/audio-key.sh "$T/empty"

  assert_eq "$(tool_rc)" 1 "broken backend must fail preflight"
  assert_grep 'runnable keyfinder-cli' "$T/out"
}

run_tests
