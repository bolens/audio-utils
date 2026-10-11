#!/usr/bin/env bash
# Functional: cue-to-flac splits a CUE+image album into per-track FLACs.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_stage_cue_album() {
  local src
  src=$(fixture cue_album)
  mkdir -p "$T/album"
  cp "$src/album/CueAlbum.flac" "$src/album/CueAlbum.cue" "$T/album/"
}

test_cue_split_track_count_and_tags() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_cue_album

  run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "cue-to-flac rc ($(tool_out | tail -3))"
  assert_file "$T/album/01 - Part One.flac"
  assert_file "$T/album/02 - Part Two.flac"
  assert_file "$T/album/03 - Part Three.flac"

  # Each track decodes cleanly and carries the CUE title.
  flac -t --totally-silent "$T/album/01 - Part One.flac" || fail "track 1 fails flac -t"
  assert_eq "$(ffprobe_tag "$T/album/02 - Part Two.flac" title)" "Part Two" "track 2 title"

  # 3 × 2s tracks: each split is ~2 seconds long.
  local dur
  dur=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/01 - Part One.flac")
  awk -v d="$dur" 'BEGIN { exit !(d > 1.8 && d < 2.2) }' \
    || fail "track 1 duration $dur not ~2s"
}

test_cue_split_dry_run_writes_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_cue_album
  run_tool conversion/cue-to-flac/cue-to-flac.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_no_file "$T/album/01 - Part One.flac"
}

test_cue_split_fractional_frames_preserves_pcm_and_album_tags() {
  require_cmd flac metaflac ffmpeg ffprobe flock cmp
  _stage_cue_album
  cat >"$T/album/CueAlbum.cue" <<'EOF'
REM DATE 2009
REM GENRE "Hard Rock"
PERFORMER "AC/DC"
TITLE "Black | Ice"
FILE "CueAlbum.flac" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    PERFORMER "Guest"
    INDEX 01 00:01:38
  TRACK 03 AUDIO
    TITLE "Three"
    INDEX 01 00:03:51
EOF
  run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "fractional split rc ($(tool_out | tail -3))"
  assert_eq "$(ffprobe_tag "$T/album/02 - Two.flac" album)" 'Black | Ice'
  assert_eq "$(ffprobe_tag "$T/album/02 - Two.flac" album_artist)" 'AC/DC'
  assert_eq "$(ffprobe_tag "$T/album/02 - Two.flac" artist)" 'Guest'
  assert_eq "$(ffprobe_tag "$T/album/02 - Two.flac" date)" 2009
  assert_eq "$(ffprobe_tag "$T/album/02 - Two.flac" genre)" 'Hard Rock'
  # 44,100 Hz: every CD frame is exactly 588 samples.
  assert_eq "$(metaflac --show-total-samples "$T/album/01 - One.flac")" 66444
  assert_eq "$(metaflac --show-total-samples "$T/album/02 - Two.flac")" 95844
  ffmpeg -nostdin -v error -i "$T/album/CueAlbum.flac" -map 0:a:0 \
    -c:a pcm_s16le -f s16le "$T/source.pcm"
  : >"$T/tracks.pcm"
  local track
  for track in '01 - One' '02 - Two' '03 - Three'; do
    ffmpeg -nostdin -v error -i "$T/album/$track.flac" -map 0:a:0 \
      -c:a pcm_s16le -f s16le - >>"$T/tracks.pcm"
  done
  cmp "$T/source.pcm" "$T/tracks.pcm" || fail "split PCM differs from image"
  assert_file "$T/album/CueAlbum.cue"
  assert_file "$T/album/CueAlbum.flac"
}

test_cue_split_rejects_late_invalid_index_without_partial_tracks() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_cue_album
  # Track 1 is valid, but the later pair is non-increasing. The parser may have
  # emitted an early record before failing; conversion must discard all records.
  sed -i 's/00:04:00/00:02:00/' "$T/album/CueAlbum.cue"
  run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "invalid late index rc"
  assert_no_file "$T/album/01 - Part One.flac"
  assert_no_file "$T/album/02 - Part Two.flac"
  assert_no_file "$T/album/03 - Part Three.flac"
  assert_file "$T/album/CueAlbum.flac"
}

test_cue_split_rejects_source_output_collision_even_with_overwrite() {
  require_cmd flac metaflac ffmpeg ffprobe flock sha256sum
  _stage_cue_album
  mv "$T/album/CueAlbum.flac" "$T/album/01 - Part One.flac"
  sed -i 's/CueAlbum.flac/01 - Part One.flac/' "$T/album/CueAlbum.cue"
  local before after
  before=$(sha256sum "$T/album/01 - Part One.flac")
  run_tool conversion/cue-to-flac/cue-to-flac.sh -y -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "source collision rc"
  assert_grep 'output collides with CUE image' "$T/out"
  after=$(sha256sum "$T/album/01 - Part One.flac")
  assert_eq "$after" "$before" "source unchanged"
  assert_no_file "$T/album/02 - Part Two.flac"
}

test_cue_split_rejects_unsupported_layouts_before_output() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_cue_album
  cp "$T/album/CueAlbum.cue" "$T/original.cue"
  local variant
  for variant in multi-file data-track malformed-track duplicate-track zero-track; do
    cp "$T/original.cue" "$T/album/CueAlbum.cue"
    case "$variant" in
      multi-file) sed -i '/TRACK 02/i FILE "CueAlbum.flac" WAVE' "$T/album/CueAlbum.cue" ;;
      data-track) sed -i 's/TRACK 02 AUDIO/TRACK 02 MODE1\/2352/' "$T/album/CueAlbum.cue" ;;
      malformed-track) sed -i 's/TRACK 02 AUDIO/TRACK x AUDIO/' "$T/album/CueAlbum.cue" ;;
      duplicate-track) sed -i 's/TRACK 02 AUDIO/TRACK 01 AUDIO/' "$T/album/CueAlbum.cue" ;;
      zero-track) sed -i 's/TRACK 02 AUDIO/TRACK 00 AUDIO/' "$T/album/CueAlbum.cue" ;;
    esac
    run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/album"
    assert_eq "$(tool_rc)" 1 "$variant rc"
    assert_no_file "$T/album/01 - Part One.flac"
    assert_no_file "$T/album/02 - Part Two.flac"
    assert_no_file "$T/album/03 - Part Three.flac"
  done
}

test_cue_split_preserves_integer_precision_and_pcm() {
  require_cmd flac metaflac ffmpeg ffprobe flock cmp
  local bits codec format first second track
  for bits in 8 16 24; do
    mkdir -p "$T/width-$bits"
    if [[ "$bits" == 8 ]]; then codec=pcm_u8; format=u8; else codec="pcm_s${bits}le"; format="s${bits}le"; fi
    ffmpeg -nostdin -v error -f lavfi \
      -i 'anoisesrc=duration=3:sample_rate=44100:seed=123' -ac 2 \
      -c:a "$codec" "$T/width-$bits/image.wav"
    flac --totally-silent -o "$T/width-$bits/image.flac" "$T/width-$bits/image.wav"
    cat >"$T/width-$bits/album.cue" <<'EOF'
FILE "image.flac" WAVE
  TRACK 01 AUDIO
    TITLE "First"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second"
    INDEX 01 00:01:38
EOF
    run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/width-$bits"
    assert_eq "$(tool_rc)" 0 "$bits-bit split rc ($(tool_out | tail -3))"
    first="$T/width-$bits/01 - First.flac"; second="$T/width-$bits/02 - Second.flac"
    assert_eq "$(metaflac --show-bps "$first")" "$bits" "output precision"
    assert_eq "$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_raw_sample \
      -of csv=p=0 "$first")" "$bits" "ffprobe output precision"
    assert_eq "$(metaflac --show-sample-rate "$first")" 44100 "sample rate"
    assert_eq "$(metaflac --show-channels "$first")" 2 "channels"
    assert_eq "$(metaflac --show-total-samples "$first")" 66444 "fractional samples"
    assert_eq "$(metaflac --show-total-samples "$second")" 65856 "tail samples"
    flac -t --totally-silent "$first" "$second"
    ffmpeg -nostdin -v error -i "$T/width-$bits/image.flac" -map 0:a:0 \
      -c:a "$codec" -f "$format" "$T/width-$bits/source.pcm"
    if [[ "$bits" == 24 ]]; then
      ffmpeg -nostdin -v error -i "$T/width-$bits/image.flac" -map 0:a:0 \
        -af aformat=sample_fmts=s16 -c:a pcm_s24le -f s24le "$T/width-$bits/quantized.pcm"
      if cmp -s "$T/width-$bits/source.pcm" "$T/width-$bits/quantized.pcm"; then
        fail "24-bit fixture lacks meaningful low bits"
      fi
    fi
    : >"$T/width-$bits/tracks.pcm"
    for track in "$first" "$second"; do
      ffmpeg -nostdin -v error -i "$track" -map 0:a:0 \
        -c:a "$codec" -f "$format" - >>"$T/width-$bits/tracks.pcm"
    done
    cmp "$T/width-$bits/source.pcm" "$T/width-$bits/tracks.pcm" \
      || fail "$bits-bit concatenated PCM differs"
  done
}

test_cue_split_rejects_unsupported_precision_before_output() {
  require_cmd flac metaflac ffmpeg ffprobe flock sha256sum
  local codec before
  for codec in pcm_s32le pcm_f32le; do
    mkdir -p "$T/$codec"
    ffmpeg -nostdin -v error -f lavfi \
      -i 'anoisesrc=duration=2:sample_rate=44100:seed=456' \
      -c:a "$codec" "$T/$codec/image.wav"
    cat >"$T/$codec/album.cue" <<'EOF'
FILE "image.wav" WAVE
  TRACK 01 AUDIO
    TITLE "First"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second"
    INDEX 01 00:01:00
EOF
    printf 'existing output must survive' >"$T/$codec/01 - First.flac"
    before=$(sha256sum "$T/$codec/01 - First.flac")
    run_tool conversion/cue-to-flac/cue-to-flac.sh -y -j 1 "$T/$codec"
    assert_eq "$(tool_rc)" 1 "$codec rejected before splitting"
    assert_eq "$(sha256sum "$T/$codec/01 - First.flac")" "$before"
    assert_no_file "$T/$codec/02 - Second.flac"
    assert_grep 'unsupported or unreadable image precision' "$T/out"
  done
}

test_cue_split_rejects_unverified_wavpack_modes() {
  require_cmd flac metaflac ffmpeg ffprobe flock wavpack wvunpack
  _stage_cue_album
  ffmpeg -nostdin -v error -i "$T/album/CueAlbum.flac" -c:a pcm_s16le "$T/image.wav"
  local mode
  for mode in lossless hybrid; do
    if [[ "$mode" == hybrid ]]; then
      wavpack -q -b2 -o "$T/album/image.wv" "$T/image.wav"
      assert_grep 'hybrid lossy' "$(wvunpack -ss "$T/album/image.wv" 2>&1)"
    else
      wavpack -q -o "$T/album/image.wv" "$T/image.wav"
    fi
    sed 's/CueAlbum.flac/image.wv/' "$T/album/CueAlbum.cue" >"$T/album/current.cue"
    rm "$T/album/CueAlbum.cue"
    run_tool conversion/cue-to-flac/cue-to-flac.sh -j 1 "$T/album"
    assert_eq "$(tool_rc)" 1 "$mode WavPack rejected"
    assert_no_file "$T/album/01 - Part One.flac"
    assert_no_file "$T/album/02 - Part Two.flac"
    mv "$T/album/current.cue" "$T/album/CueAlbum.cue"
    sed -i 's/image.wv/CueAlbum.flac/' "$T/album/CueAlbum.cue"
    rm "$T/album/image.wv"
  done
}

run_tests
