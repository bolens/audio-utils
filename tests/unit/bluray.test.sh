#!/usr/bin/env bash
# Unit tests: Blu-ray path discovery and internal media transport.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_bluray() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/pipeline/bluray.sh"
  log_err() { :; }
  log_note() { :; }
  log_info() { :; }
  log_verbose() { :; }
}

test_plain_media_print0_preserves_newline_and_sort_order() {
  _load_bluray
  local first=$'A\nLive.mkv' second='B.m2ts' item
  local -a found=()
  mkdir -p "$T/media"
  : >"$T/media/$second"
  : >"$T/media/$first"
  while IFS= read -r -d '' item; do
    found+=("$item")
  done < <(bluray_list_plain_media --print0 "$T/media")
  assert_eq "${#found[@]}" "2"
  assert_eq "${found[0]}" "$T/media/$first"
  assert_eq "${found[1]}" "$T/media/$second"
}

test_decrypt_plain_media_emits_nul_records() {
  _load_bluray
  bluray_media_readable() { [[ $1 != *unreadable* ]]; }
  local good=$'Good\nTitle.mkv' bad='unreadable.mkv' item
  local -a found=()
  mkdir -p "$T/media" "$T/out"
  : >"$T/media/$good"
  : >"$T/media/$bad"
  while IFS= read -r -d '' item; do
    found+=("$item")
  done < <(bluray_decrypt_or_copy "$T/media" "$T/out")
  assert_eq "${#found[@]}" "1"
  assert_eq "${found[0]}" "$T/media/$good"
}

test_decrypt_plain_media_fails_on_partial_unreadability() {
  _load_bluray
  bluray_media_readable() { [[ $1 != *bad* ]]; }
  mkdir -p "$T/media" "$T/out"
  : >"$T/media/good.mkv"
  : >"$T/media/bad.mkv"
  assert_exit 1 bluray_decrypt_or_copy "$T/media" "$T/out"
}

test_resolve_media_dir_with_many_files_under_pipefail() {
  _load_bluray
  mkdir -p "$T/media"
  local i
  for ((i = 0; i < 200; i++)); do
    : >"$T/media/title-$i.mkv"
  done
  assert_eq "$(bluray_resolve_input "$T/media")" "media_dir"
}

test_resolve_media_dir_accepts_ts() {
  _load_bluray
  mkdir -p "$T/media"
  : >"$T/media/title.ts"
  assert_eq "$(bluray_resolve_input "$T/media")" "media_dir"
}

test_makemkv_source_uses_explicit_schemes() {
  _load_bluray
  mkdir -p "$T/disc/BDMV"
  assert_eq "$(bluray_makemkv_source "$T/disc")" "file:$T/disc"
  assert_eq "$(bluray_makemkv_source /dev/sr7)" "dev:/dev/sr7"
  : >"$T/disc.iso"
  assert_eq "$(bluray_makemkv_source "$T/disc.iso")" "iso:$T/disc.iso"
}

test_makemkv_backup_passes_explicit_source() {
  _load_bluray
  mkdir -p "$T/bin" "$T/disc/BDMV" "$T/out"
  # shellcheck disable=SC2016 # mock script expands these at execution time
  printf '%s\n' '#!/usr/bin/env bash' \
    'if [[ " $* " == *" info "* ]]; then printf '\''TINFO:0,9,0,"0:01:00"\n'\''; exit; fi' \
    'dest=${!#}; printf x >"$dest/title.mkv"' \
    'printf '\''%s\0'\'' "$@" >"$MAKE_ARGS"' >"$T/bin/makemkvcon"
  chmod +x "$T/bin/makemkvcon"
  AUDIO_UTILS_MAKEMKV="$T/bin/makemkvcon"
  MAKE_ARGS="$T/args"
  export AUDIO_UTILS_MAKEMKV MAKE_ARGS
  bluray_makemkv_backup "$T/disc" "$T/out"
  local -a args
  mapfile -d '' -t args <"$T/args"
  assert_eq "${args[0]}" "--robot"
  assert_eq "${args[1]}" "--minlength=0"
  assert_eq "${args[2]}" "mkv"
  assert_eq "${args[3]}" "file:$T/disc"
  assert_eq "${args[4]}" "all"
  assert_eq "${args[5]}" "$T/out"
}

test_makemkv_backup_honors_title_and_minlength() {
  _load_bluray
  mkdir -p "$T/bin" "$T/disc/BDMV" "$T/out"
  # shellcheck disable=SC2016 # mock script expands these at execution time
  printf '%s\n' '#!/usr/bin/env bash' \
    'if [[ " $* " == *" info "* ]]; then printf '\''TINFO:7,9,0,"0:02:00"\n'\''; exit; fi' \
    'dest=${!#}; printf x >"$dest/title.mkv"' \
    'printf '\''%s\0'\'' "$@" >"$MAKE_ARGS"' >"$T/bin/makemkvcon"
  chmod +x "$T/bin/makemkvcon"
  AUDIO_UTILS_MAKEMKV="$T/bin/makemkvcon"
  AUDIO_UTILS_BD_TITLE=7
  AUDIO_UTILS_BD_MIN_LENGTH=90
  MAKE_ARGS="$T/args"
  export AUDIO_UTILS_MAKEMKV AUDIO_UTILS_BD_TITLE AUDIO_UTILS_BD_MIN_LENGTH MAKE_ARGS
  bluray_makemkv_backup "$T/disc" "$T/out"
  local -a args
  mapfile -d '' -t args <"$T/args"
  assert_eq "${args[1]}" "--minlength=90"
  assert_eq "${args[4]}" 7
}

test_device_id_is_stable_and_disc_specific() {
  _load_bluray
  mkdir -p "$T/bin"
  # shellcheck disable=SC2016 # mock script expands these at execution time
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf '\''CINFO:2,0,"%s"\nTINFO:0,2,0,"Main"\n'\'' "$MOCK_DISC"' \
    >"$T/bin/makemkvcon"
  chmod +x "$T/bin/makemkvcon"
  AUDIO_UTILS_MAKEMKV="$T/bin/makemkvcon"
  MOCK_DISC=alpha
  export AUDIO_UTILS_MAKEMKV MOCK_DISC
  local alpha alpha_again beta
  alpha=$(bluray_device_id /dev/sr0)
  alpha_again=$(bluray_device_id /dev/sr0)
  MOCK_DISC=beta
  export MOCK_DISC
  beta=$(bluray_device_id /dev/sr0)
  assert_eq "$alpha" "$alpha_again"
  [[ "$alpha" == disc-* ]] || fail "unexpected disc id: $alpha"
  [[ "$alpha" != "$beta" ]] || fail "different discs produced the same id"
}

test_device_id_accepts_valid_operator_override() {
  _load_bluray
  AUDIO_UTILS_BD_DISC_ID='my-disc_01'
  export AUDIO_UTILS_BD_DISC_ID
  assert_eq "$(bluray_device_id /dev/sr0)" my-disc_01
  AUDIO_UTILS_BD_DISC_ID='../unsafe'
  export AUDIO_UTILS_BD_DISC_ID
  assert_exit 1 bluray_device_id /dev/sr0
}

test_decode_length_rejects_truncation() {
  _load_bluray
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/conversion/bluray-to-flac/lib/convert.sh"
  _bluray_stream_field() { printf '%s\n' 10.0; }
  audio_duration_sec() { printf '%s\n' 9.0; }
  assert_exit 1 _bluray_verify_decode_length source.mkv 0 decoded.wav
  audio_duration_sec() { printf '%s\n' 9.9; }
  _bluray_verify_decode_length source.mkv 0 decoded.wav
}

test_decode_format_checks_exact_samples_when_available() {
  _load_bluray
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/conversion/bluray-to-flac/lib/convert.sh"
  _bluray_stream_field() {
    case "$3" in
      sample_rate) printf '%s\n' 48000 ;;
      channels) printf '%s\n' 2 ;;
      duration_ts) printf '%s\n' 48000 ;;
      time_base) printf '%s\n' 1/48000 ;;
    esac
  }
  audio_sample_rate() { printf '%s\n' 48000; }
  audio_channels() { printf '%s\n' 2; }
  audio_samples() { printf '%s\n' 47999; }
  assert_exit 1 _bluray_verify_decode_format source.mkv 0 decoded.wav
  audio_samples() { printf '%s\n' 48000; }
  _bluray_verify_decode_format source.mkv 0 decoded.wav
}

test_source_duration_falls_back_to_matroska_tag() {
  _load_bluray
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/conversion/bluray-to-flac/lib/convert.sh"
  _bluray_stream_field() { printf '%s\n' N/A; }
  ffprobe() { printf '%s\n' '00:01:02.500000000'; }
  assert_eq "$(_bluray_source_duration source.mkv 0)" "62.500000000"
}

test_resolve_iso_as_disc_image() {
  _load_bluray
  : >"$T/disc.iso"
  assert_eq "$(bluray_resolve_input "$T/disc.iso")" disc_image
}

test_expected_title_count_applies_minimum() {
  _load_bluray
  local info
  info=$'TINFO:0,9,0,"0:00:20"\nTINFO:1,9,0,"0:01:00"'
  assert_eq "$(printf '%s\n' "$info" | bluray_expected_title_count all 30)" 1
  assert_eq "$(printf '%s\n' "$info" | bluray_expected_title_count all 0)" 2
  assert_eq "$(printf '%s\n' "$info" | bluray_expected_title_count 7 30)" 1
}

test_captured_makemkv_transcript_inventory() {
  _load_bluray
  local info="$AU_REPO_ROOT/tests/assets/makemkv/robot-info.txt"
  assert_eq "$(bluray_expected_title_count all 0 <"$info")" 3
  assert_eq "$(bluray_expected_title_count all 30 <"$info")" 2
}

test_captured_makemkv_warning_is_classified() {
  _load_bluray
  local transcript="$AU_REPO_ROOT/tests/assets/makemkv/robot-warning.txt"
  assert_grep 'corrupt or invalid' "$(bluray_extract_warnings "$transcript")"
}

test_resume_reuses_complete_staged_titles() {
  _load_bluray
  mkdir -p "$T/disc/BDMV" "$T/out"
  : >"$T/out/title.mkv"
  AUDIO_UTILS_BD_RESUME=1
  export AUDIO_UTILS_BD_RESUME
  bluray_media_readable() { return 0; }
  bluray_makemkv_backup() { fail 'MakeMKV should not run for complete stage'; }
  local item
  IFS= read -r -d '' item < <(bluray_decrypt_or_copy "$T/disc" "$T/out")
  assert_eq "$item" "$T/out/title.mkv"
}

test_stage_identity_binds_title_selection() {
  _load_bluray
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/conversion/bluray-to-flac/lib/convert.sh"
  mkdir -p "$T/disc/BDMV/PLAYLIST"
  printf x >"$T/disc/BDMV/index.bdmv"
  printf y >"$T/disc/BDMV/PLAYLIST/00001.mpls"
  AUDIO_UTILS_BD_TITLE=all
  AUDIO_UTILS_BD_MIN_LENGTH=0
  local all one
  all=$(_bluray_stage_identity "$T/disc" bdmv)
  AUDIO_UTILS_BD_TITLE=1
  one=$(_bluray_stage_identity "$T/disc" bdmv)
  [[ "$all" != "$one" ]] || fail "stage identity ignored title selection"
}

test_makemkv_backup_rejects_partial_title_inventory() {
  _load_bluray
  mkdir -p "$T/bin" "$T/disc/BDMV" "$T/out"
  # shellcheck disable=SC2016 # mock script expands these at execution time
  printf '%s\n' '#!/usr/bin/env bash' \
    'if [[ " $* " == *" info "* ]]; then' \
    '  printf '\''TINFO:0,9,0,"0:01:00"\nTINFO:1,9,0,"0:02:00"\n'\''' \
    '  exit' \
    'fi' \
    'dest=${!#}; printf x >"$dest/only-one.mkv"' >"$T/bin/makemkvcon"
  chmod +x "$T/bin/makemkvcon"
  AUDIO_UTILS_MAKEMKV="$T/bin/makemkvcon"
  AUDIO_UTILS_BD_TITLE=all
  AUDIO_UTILS_BD_MIN_LENGTH=0
  export AUDIO_UTILS_MAKEMKV AUDIO_UTILS_BD_TITLE AUDIO_UTILS_BD_MIN_LENGTH
  assert_exit 1 bluray_makemkv_backup "$T/disc" "$T/out"
}

test_iso_dry_run_uses_image_specific_output_dir() {
  _load_bluray
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/conversion/bluray-to-flac/lib/convert.sh"
  : >"$T/concert.iso"
  DRY_RUN=1
  local message=""
  bluray_makemkv_bin() { printf '%s\n' /mock/makemkvcon; }
  log_progress() { message=$*; }
  convert_one "$T/concert.iso"
  [[ "$message" == *"$T/concert.flac/"* ]] || fail "unexpected ISO output: $message"
}

test_disk_preflight_rejects_insufficient_space() {
  _load_bluray
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/conversion/bluray-to-flac/lib/convert.sh"
  _bluray_source_size() { printf '%s\n' 100; }
  bytes_avail() { printf '%s\n' 399; }
  AU_DISK_FACTOR=4
  assert_exit 1 _bluray_check_disk_preflight source media_file "$T"
  bytes_avail() { printf '%s\n' 400; }
  _bluray_check_disk_preflight source media_file "$T"
}

test_bdmv_never_falls_back_to_raw_stream_clips() {
  _load_bluray
  mkdir -p "$T/disc/BDMV/STREAM" "$T/out"
  : >"$T/disc/BDMV/STREAM/00001.m2ts"
  bluray_makemkv_bin() { return 1; }
  bluray_media_readable() { return 0; }
  assert_exit 1 bluray_decrypt_or_copy "$T/disc" "$T/out"
}

run_tests
