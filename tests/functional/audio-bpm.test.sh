#!/usr/bin/env bash
# Functional: audio-bpm detects tempo from a click track and writes BPM tags
# (metaflac for FLAC, TBPM remux for MP3). Gated on bpm-tools/aubio.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_require_bpm_backend() {
  command -v bpm >/dev/null 2>&1 || command -v aubio >/dev/null 2>&1 \
    || skip "no bpm (bpm-tools) or aubio"
}

# 120 BPM click track: a short 1 kHz burst every 0.5 s.
_mk_click() { # dest (.flac or .mp3)
  local dest=$1
  local -a enc=(-c:a flac)
  [[ "$dest" == *.mp3 ]] && enc=(-c:a libmp3lame -b:a 128k)
  ffmpeg -nostdin -v error -y \
    -f lavfi -i "sine=frequency=1000:sample_rate=44100:duration=15" \
    -af "volume='if(lt(mod(t,0.5),0.08),1,0)':eval=frame" \
    "${enc[@]}" "$dest"
}

_assert_bpm_near_120() { # value label
  [[ "$1" =~ ^[0-9]+$ ]] || fail "$2: BPM not an integer: '$1'"
  (($1 >= 110 && $1 <= 130)) || fail "$2: BPM $1 not near 120"
}

test_bpm_tags_flac_click_track() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_bpm_backend
  mkdir -p "$T/album"
  _mk_click "$T/album/click.flac"

  run_tool util/audio/audio-bpm/audio-bpm.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local bpm
  bpm=$(metaflac --show-tag=BPM "$T/album/click.flac" | cut -d= -f2)
  _assert_bpm_near_120 "$bpm" "flac"
}

test_bpm_tags_mp3_via_remux_without_reencode() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  _require_bpm_backend
  mkdir -p "$T/album"
  _mk_click "$T/album/click.mp3"
  local before
  before=$(audio_md5 "$T/album/click.mp3")

  run_tool util/audio/audio-bpm/audio-bpm.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  local bpm
  bpm=$(ffprobe -v error -show_entries format_tags=TBPM \
    -of default=noprint_wrappers=1:nokey=1 "$T/album/click.mp3")
  _assert_bpm_near_120 "$bpm" "mp3"
  assert_eq "$(audio_md5 "$T/album/click.mp3")" "$before" \
    "audio must not be re-encoded"
}

test_bpm_skips_existing_tag_without_overwrite() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_bpm_backend
  mkdir -p "$T/album"
  _mk_click "$T/album/click.flac"
  metaflac --set-tag="BPM=99" "$T/album/click.flac"

  run_tool util/audio/audio-bpm/audio-bpm.sh -j 1 -S "$T/s.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(metaflac --show-tag=BPM "$T/album/click.flac" | cut -d= -f2)" \
    "99" "existing tag must survive without -y"
  assert_grep "skipped-existing" "$T/s.csv"
}

test_bpm_dry_run_writes_nothing() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_bpm_backend
  mkdir -p "$T/album"
  _mk_click "$T/album/click.flac"

  run_tool util/audio/audio-bpm/audio-bpm.sh -n "$T/album"
  assert_eq "$(tool_rc)" 0 "dry-run rc"
  assert_grep "would tag-bpm" "$T/out"
  [[ -z "$(metaflac --show-tag=BPM "$T/album/click.flac")" ]] \
    || fail "dry run must not tag"
}

test_bpm_rejects_delete_source_flags() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _require_bpm_backend
  mkdir -p "$T/album"
  run_tool util/audio/audio-bpm/audio-bpm.sh -d "$T/album"
  [[ "$(tool_rc)" -ne 0 ]] || fail "-d must be rejected"
  assert_grep "does not support -d" "$T/out"
}

run_tests
