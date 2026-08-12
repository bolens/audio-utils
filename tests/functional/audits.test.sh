#!/usr/bin/env bash
# Functional: album-audit, path-audit, silence-detect, lossy-audit.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_stage_album() {
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
}

_audit_cover() {
  ffmpeg -nostdin -v error -y -f lavfi -i 'color=c=blue:size=32x32:d=1' \
    -frames:v 1 "$1"
}

test_album_audit_clean_passes() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_album
  run_tool util/audit/album-audit/album-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean album rc ($(tool_out | tail -3))"
}

test_album_audit_flags_mixed_album_tag() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_album
  metaflac --remove-tag=ALBUM --set-tag="ALBUM=Different Album" \
    "$T/album/02 - Track Two.flac"
  run_tool util/audit/album-audit/album-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "mixed album rc ($(tool_out | tail -3))"
}

test_album_audit_flags_duplicate_tracknumber() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  _stage_album
  metaflac --remove-tag=TRACKNUMBER --set-tag="TRACKNUMBER=1" \
    "$T/album/02 - Track Two.flac"
  run_tool util/audit/album-audit/album-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 1 "dupe tracknumber rc ($(tool_out | tail -3))"
}

test_path_audit_clean_passes_bad_name_fails() {
  require_cmd flock
  _stage_album
  run_tool util/audit/path-audit/path-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "clean names rc ($(tool_out | tail -3))"

  cp "$T/album/01 - Track One.flac" "$T/album/bad:name?.flac"
  run_tool util/audit/path-audit/path-audit.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "bad name rc ($(tool_out | tail -3))"
  assert_grep "bad:name" "$T/failures.log"
}

test_path_audit_checks_ancestors_and_case_collisions() {
  require_cmd flock
  _stage_album
  mkdir -p "$T/bad:parent/album" "$T/collision"
  cp "$T/album/01 - Track One.flac" "$T/bad:parent/album/track.flac"
  run_tool util/audit/path-audit/path-audit.sh "$T/bad:parent/album"
  assert_eq "$(tool_rc)" 1
  assert_grep 'dir-illegal-chars' "$T/out"

  cp "$T/album/01 - Track One.flac" "$T/collision/Track.flac"
  cp "$T/album/01 - Track One.flac" "$T/collision/track.FLAC"
  run_tool util/audit/path-audit/path-audit.sh -j 1 "$T/collision"
  assert_eq "$(tool_rc)" 1
  assert_grep 'casefold-collision' "$T/out"
}

test_silence_detect_flags_leading_silence() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  mkdir -p "$T/album"
  # 2.5 s of leading silence then 1 s of tone (default threshold: 1 s).
  ffmpeg -nostdin -v error -y \
    -f lavfi -i "sine=frequency=440:duration=1:sample_rate=44100" \
    -af "adelay=2500:all=1" -ac 2 -c:a pcm_s16le "$T/album/leading.wav"
  run_tool util/audit/silence-detect/silence-detect.sh -j 1 -L "$T/failures.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "leading silence rc ($(tool_out | tail -3))"
  assert_grep "leading.wav" "$T/failures.log"
}

test_silence_detect_passes_normal_audio() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  cp "$src/noise.wav" "$T/album/"
  run_tool util/audit/silence-detect/silence-detect.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "normal audio rc ($(tool_out | tail -5))"
}

test_lossy_audit_passes_tagged_with_cover() {
  require_cmd ffmpeg ffprobe flock
  local src
  src=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$src/track.mp3" "$T/album/"
  _audit_cover "$T/album/cover.jpg"
  # A pure-sine VBR MP3 encodes around 35 kbps — keep the floor below that.
  run_tool util/audit/lossy-audit/lossy-audit.sh -j 1 --min-kbps=16 "$T/album"
  assert_eq "$(tool_rc)" 0 "tagged+cover rc ($(tool_out | tail -3))"
}

test_lossy_audit_flags_missing_cover_and_low_bitrate() {
  require_cmd ffmpeg ffprobe flock
  local src
  src=$(fixture lossy)
  mkdir -p "$T/nocover" "$T/lowrate"
  cp "$src/track.mp3" "$T/nocover/"
  run_tool util/audit/lossy-audit/lossy-audit.sh -j 1 --min-kbps=16 \
    -L "$T/failures.log" "$T/nocover"
  assert_eq "$(tool_rc)" 1 "missing cover rc ($(tool_out | tail -3))"
  assert_grep "missing-or-invalid-cover" "$T/failures.log"

  cp "$src/track.mp3" "$T/lowrate/"
  _audit_cover "$T/lowrate/cover.jpg"
  run_tool util/audit/lossy-audit/lossy-audit.sh -j 1 --min-kbps=1000 "$T/lowrate"
  assert_eq "$(tool_rc)" 1 "bitrate floor rc ($(tool_out | tail -3))"
}

test_silence_detect_rejects_decode_failure() {
  require_cmd ffmpeg ffprobe flock awk
  mkdir -p "$T/bad"
  printf 'not audio' >"$T/bad/broken.wav"
  run_tool util/audit/silence-detect/silence-detect.sh -j 1 "$T/bad"
  assert_eq "$(tool_rc)" 1
  assert_grep 'duration probe failed\|audio decode failed' "$T/out"
}

test_lossy_audit_rejects_truncated_payload_and_invalid_cover() {
  require_cmd ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  mkdir -p "$T/bad"
  ffmpeg -nostdin -v error -y -f lavfi -i 'sine=duration=4' -c:a libmp3lame \
    -metadata artist=A -metadata album=B -metadata title=C -metadata track=1 \
    "$T/bad/truncated.mp3"
  truncate -s 1024 "$T/bad/truncated.mp3"
  printf invalid >"$T/bad/cover.jpg"
  run_tool util/audit/lossy-audit/lossy-audit.sh --min-kbps=1 "$T/bad"
  assert_eq "$(tool_rc)" 1
  assert_grep 'audio decode failed\|missing-or-invalid-cover' "$T/out"
}

test_audit_numeric_options_reject_malformed_values() {
  mkdir -p "$T/empty"
  local tool option rc
  while IFS='|' read -r tool option; do
    run_tool "util/audit/$tool/$tool.sh" "$option" "$T/empty"
    rc=$(tool_rc)
    assert_eq "$rc" 2 "$tool accepted $option"
    assert_grep "Error:" "$T/out"
  done <<'EOF'
lossy-audit|--min-kbps=0
lossy-audit|--min-kbps=-1
lossy-audit|--min-kbps=128oops
lossy-audit|--min-kbps=1.5
silence-detect|--silence-sec=0
silence-detect|--silence-sec=1oops
silence-detect|--silence-sec=.5
silence-detect|--silence-db=-50dB
silence-detect|--silence-db=1
EOF
}

test_audit_numeric_options_accept_boundaries() {
  require_cmd ffmpeg ffprobe flock awk
  mkdir -p "$T/empty"

  run_tool util/audit/lossy-audit/lossy-audit.sh --min-kbps=1 "$T/empty"
  assert_eq "$(tool_rc)" 0 "lossy-audit minimum bitrate boundary"

  run_tool util/audit/silence-detect/silence-detect.sh \
    --silence-sec=0.1 --silence-db=0 "$T/empty"
  assert_eq "$(tool_rc)" 0 "silence-detect numeric boundaries"
}

run_tests
