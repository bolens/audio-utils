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

test_bdmv_never_falls_back_to_raw_stream_clips() {
  _load_bluray
  mkdir -p "$T/disc/BDMV/STREAM" "$T/out"
  : >"$T/disc/BDMV/STREAM/00001.m2ts"
  bluray_makemkv_bin() { return 1; }
  bluray_media_readable() { return 0; }
  assert_exit 1 bluray_decrypt_or_copy "$T/disc" "$T/out"
}

run_tests
