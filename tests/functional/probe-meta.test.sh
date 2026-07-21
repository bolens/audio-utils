#!/usr/bin/env bash
# Functional-unit: lib/media/probe.sh and audio_meta.sh against real files.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_load() {
  QUIET=0 VERBOSE=0
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/log.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/tags.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/probe.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/audio_meta.sh"
}

test_probe_basics_on_flac() {
  require_cmd flac metaflac ffmpeg ffprobe
  _load
  local src
  src=$(fixture flac_tagged)

  assert_eq "$(audio_codec "$src/track.flac")" flac
  assert_eq "$(audio_channels "$src/track.flac")" 2
  assert_eq "$(audio_sample_rate "$src/track.flac")" 44100
  assert_eq "$(audio_bits_per_sample "$src/track.flac")" 16
  assert_eq "$(audio_samples "$src/track.flac")" 88200 "2s at 44.1kHz"
  # Duration ~2s
  local dur
  dur=$(audio_duration_sec "$src/track.flac")
  awk -v d="$dur" 'BEGIN { exit (d > 1.9 && d < 2.1) ? 0 : 1 }' \
    || fail "duration $dur not ~2s"
}

test_sibling_matches_source_true_and_false() {
  require_cmd flac metaflac ffmpeg ffprobe
  _load
  local a b
  a=$(fixture flac_tagged)     # sine
  b=$(fixture wav_sine)

  sibling_matches_source "$b/sine.wav" "$a/track.flac" \
    || fail "same audio must match"
  sibling_matches_source "$b/noise.wav" "$a/track.flac" \
    && fail "different audio must not match"
  sibling_matches_source "$b/missing.wav" "$a/track.flac" \
    && fail "missing file must not match"
  return 0
}

test_float_abs_peak_in_unit_range() {
  require_cmd ffmpeg
  _load
  # Contract: input is float PCM (astats reports levels in the native
  # domain, so integer files would report raw sample values).
  local src peak
  src=$(fixture wav_sine)
  ffmpeg -nostdin -v error -y -i "$src/noise.wav" -c:a pcm_f32le "$T/f32.wav"
  peak=$(float_abs_peak "$T/f32.wav") || fail "peak probe failed"
  awk -v p="$peak" 'BEGIN { exit (p > 0.1 && p <= 1.0) ? 0 : 1 }' \
    || fail "peak $peak outside (0.1, 1.0]"
}

test_meta_get_is_case_insensitive_across_formats() {
  require_cmd flac metaflac ffmpeg ffprobe
  _load
  local f l
  f=$(fixture flac_tagged)
  l=$(fixture lossy)

  assert_eq "$(audio_meta_get "$f/track.flac" ARTIST)" "Test Artist"
  assert_eq "$(audio_meta_get "$f/track.flac" artist)" "Test Artist"
  assert_eq "$(audio_meta_get "$l/track.mp3" ARTIST)" "Test Artist"
  assert_eq "$(audio_meta_get "$l/track.m4a" title)" "Test Title"
  assert_eq "$(audio_meta_get "$l/track.mp3" NOPETAG)" "" "missing tag empty"
}

test_bitrate_kbps_plausible_for_mp3() {
  require_cmd ffmpeg ffprobe
  _load
  local l kbps
  l=$(fixture lossy)
  kbps=$(audio_bitrate_kbps "$l/track.mp3") || fail "bitrate probe failed"
  ((kbps >= 8 && kbps <= 320)) || fail "mp3 bitrate $kbps implausible"
}

test_has_cover_detection() {
  require_cmd flac metaflac ffmpeg ffprobe
  _load
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  audio_has_cover "$T/album/track.flac" && fail "bare flac has no cover"
  ffmpeg -nostdin -v error -y -f lavfi -i "color=c=red:size=48x48:d=1" \
    -frames:v 1 "$T/cover.jpg"
  metaflac --import-picture-from="$T/cover.jpg" "$T/album/track.flac"
  audio_has_cover "$T/album/track.flac" || fail "cover not detected after embed"
}

test_remux_tags_preserves_audio_and_rejects_nothing_valid() {
  require_cmd ffmpeg ffprobe
  _load
  local l
  l=$(fixture lossy)
  mkdir -p "$T/w"
  cp "$l/track.mp3" "$T/w/in.mp3"

  audio_meta_remux_tags "$T/w/in.mp3" "$T/w/out.mp3" \
    -metadata title="Renamed" || fail "remux failed"
  assert_eq "$(ffprobe_tag "$T/w/out.mp3" title)" "Renamed"
  assert_eq "$(audio_md5 "$T/w/out.mp3")" "$(audio_md5 "$T/w/in.mp3")" \
    "audio must be untouched"
}

test_relpath_under() {
  _load
  mkdir -p "$T/root/sub/dir"
  : >"$T/root/sub/dir/f.flac"
  assert_eq "$(audio_relpath_under "$T/root" "$T/root/sub/dir/f.flac")" \
    "sub/dir/f.flac"
  local rc=0
  audio_relpath_under "$T/root/sub" "$T/root/other.flac" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1 "outside root must fail"
}

run_tests
