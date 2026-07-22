#!/usr/bin/env bash
# Functional: gapless-audit, spectrogram-export, audio-dupes (md5 + fingerprint),
# audio-tags normalization across formats.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

# --- gapless-audit ------------------------------------------------------------

test_gapless_lame_mp3_passes() {
  require_cmd flac metaflac ffmpeg flock
  require_ffmpeg_encoder libmp3lame
  local src
  src=$(fixture lossy)
  mkdir -p "$T/album"
  cp "$src/track.mp3" "$T/album/"
  run_tool util/audit/gapless-audit/gapless-audit.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "lame mp3 has Xing+encoder tag ($(tool_out | tail -3))"
}

test_gapless_flags_adts_aac_and_bare_m4a() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  # ADTS AAC: container cannot carry gapless info — always flagged.
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a aac -f adts "$T/album/raw.aac"

  run_tool util/audit/gapless-audit/gapless-audit.sh -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "adts must be flagged"
  assert_grep "adts-no-gapless-metadata" "$T/fails.log"

  # M4A without iTunSMPB (ffmpeg's aac muxer does not write it).
  mkdir -p "$T/m4a"
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a aac "$T/m4a/plain.m4a"
  run_tool util/audit/gapless-audit/gapless-audit.sh -j 1 -L "$T/fails2.log" "$T/m4a"
  assert_eq "$(tool_rc)" 1 "m4a without iTunSMPB flagged"
  assert_grep "no-itunsmpb" "$T/fails2.log"
}

# --- spectrogram-export ---------------------------------------------------------

test_spectrogram_renders_png_beside_source() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"

  run_tool util/audit/spectrogram-export/spectrogram-export.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_file "$T/album/track.flac.spectrogram.png"
  [[ -s "$T/album/track.flac.spectrogram.png" ]] || fail "empty png"
}

test_spectrogram_skips_existing_without_overwrite() {
  require_cmd flac metaflac ffmpeg flock
  local src
  src=$(fixture flac_tagged)
  mkdir -p "$T/album"
  cp "$src/track.flac" "$T/album/"
  printf 'sentinel' >"$T/album/track.flac.spectrogram.png"

  run_tool util/audit/spectrogram-export/spectrogram-export.sh -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(cat "$T/album/track.flac.spectrogram.png")" "sentinel" \
    "existing png must survive without -y"

  run_tool util/audit/spectrogram-export/spectrogram-export.sh -j 1 -y "$T/album"
  assert_eq "$(tool_rc)" 0 "-y rc"
  [[ "$(cat "$T/album/track.flac.spectrogram.png")" != "sentinel" ]] \
    || fail "-y must re-render"
}

# --- audio-dupes (md5 mode) ------------------------------------------------------

test_audio_dupes_md5_flags_cross_format_duplicates() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture dupe_pair)
  mkdir -p "$T/album"
  cp "$src/original.flac" "$src/copy of original.flac" "$T/album/"

  run_tool util/audio/audio-dupes/audio-dupes.sh -j 1 -M "$T/album"
  assert_eq "$(tool_rc)" 1 "identical audio must be flagged"
  assert_grep "original.flac" "$T/out"
}

test_audio_dupes_md5_clean_library_passes() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
  run_tool util/audio/audio-dupes/audio-dupes.sh -j 1 -M "$T/album"
  assert_eq "$(tool_rc)" 0 "distinct tracks are not dupes ($(tool_out | tail -3))"
}

test_audio_dupes_fingerprint_flags_identical_audio() {
  require_cmd flac metaflac ffmpeg ffprobe flock fpcalc
  local src
  src=$(fixture dupe_pair)
  mkdir -p "$T/album"
  cp "$src/original.flac" "$src/copy of original.flac" "$T/album/"

  run_tool util/audio/audio-dupes/audio-dupes.sh -j 1 --fingerprint "$T/album"
  assert_eq "$(tool_rc)" 1 "fingerprint mode must flag dupes ($(tool_out | tail -5))"
  assert_grep "original.flac" "$T/out"
}

# --- audio-tags -------------------------------------------------------------------

test_audio_tags_normalizes_flac_track_and_fills_albumartist() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  flac --totally-silent -f -o "$T/album/track.flac" "$src/sine.wav"
  metaflac --set-tag="ARTIST=Solo Artist" --set-tag="ALBUM=Album" \
    --set-tag="TITLE=Song" --set-tag="TRACKNUMBER=3" \
    --set-tag="ENCODER=junkware 1.0" "$T/album/track.flac"

  run_tool util/audio/audio-tags/audio-tags.sh -j 1 -A "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_grep "TRACKNUMBER=03" "$(metaflac --show-tag=TRACKNUMBER "$T/album/track.flac")"
  assert_grep "ALBUMARTIST=Solo Artist" \
    "$(metaflac --show-tag=ALBUMARTIST "$T/album/track.flac")"
  assert_eq "$(metaflac --show-tag=ENCODER "$T/album/track.flac")" "" \
    "junk ENCODER tag stripped"
}

test_audio_tags_normalizes_mp3_via_remux() {
  require_cmd flac metaflac ffmpeg ffprobe flock
  require_ffmpeg_encoder libmp3lame
  local src
  src=$(fixture wav_sine)
  mkdir -p "$T/album"
  ffmpeg -nostdin -v error -y -i "$src/sine.wav" -c:a libmp3lame -q:a 7 \
    -metadata artist="MP3 Artist" -metadata title="Song" \
    -metadata track=5 -write_xing 1 "$T/album/track.mp3"
  local before
  before=$(audio_md5 "$T/album/track.mp3")

  run_tool util/audio/audio-tags/audio-tags.sh -j 1 -A "$T/album"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  assert_eq "$(ffprobe_tag "$T/album/track.mp3" track)" "05" "track zero-padded"
  assert_eq "$(ffprobe_tag "$T/album/track.mp3" album_artist)" "MP3 Artist" \
    "albumartist filled"
  assert_eq "$(audio_md5 "$T/album/track.mp3")" "$before" \
    "remux must not re-encode audio"
}

run_tests
