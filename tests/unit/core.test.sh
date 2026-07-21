#!/usr/bin/env bash
# Unit tests: lib/core compat.sh, util.sh, log.sh escaping helpers.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_compat() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
}

_load_util() {
  _load_compat
  log_err() { echo "$@" >&2; }
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/util.sh"
}

_load_log_helpers() {
  # csv_escape / json_str / append_locked are self-contained in log.sh, but
  # the file expects logging globals; source into a controlled env.
  QUIET=0 VERBOSE=0
  audio_codec() { echo flac; }
  file_bytes() { echo 0; }
  audio_samples() { echo 0; }
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/log.sh"
}

# --- compat.sh ----------------------------------------------------------------

test_abspath_resolves_relative_dir() {
  _load_compat
  mkdir -p "$T/a/b"
  cd "$T/a"
  assert_eq "$(au_abspath b)" "$(readlink -f "$T/a/b")"
}

test_abspath_nonexistent_file_keeps_basename() {
  _load_compat
  local out
  out=$(au_abspath "$T/no-such-dir-yet/file.flac")
  assert_grep "/file.flac$" "$out"
}

test_file_bytes_and_sha256() {
  _load_compat
  printf 'hello' >"$T/f.txt"
  assert_eq "$(au_file_bytes "$T/f.txt")" 5
  assert_eq "$(au_file_bytes "$T/missing")" 0
  assert_eq "$(au_sha256 "$T/f.txt")" \
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  assert_eq "$(au_sha256_str hello)" \
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
}

test_cpu_count_is_numeric() {
  _load_compat
  [[ "$(au_cpu_count)" =~ ^[0-9]+$ ]] || fail "au_cpu_count not numeric"
}

test_iso_timestamp_shape() {
  _load_compat
  [[ "$(au_iso_timestamp)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] \
    || fail "timestamp not ISO-8601"
}

test_bytes_avail_positive() {
  _load_compat
  local n
  n=$(au_bytes_avail "$T")
  [[ "$n" =~ ^[0-9]+$ && "$n" -gt 0 ]] || fail "au_bytes_avail: got '$n'"
}

# --- util.sh -------------------------------------------------------------------

test_default_jobs_at_least_one() {
  _load_util
  [[ "$(default_jobs)" =~ ^[1-9][0-9]*$ ]] || fail "default_jobs invalid"
}

test_require_cmds_reports_all_missing() {
  _load_util
  local rc=0 err
  err=$(require_cmds bash definitely-not-a-cmd also-missing 2>&1) || rc=$?
  assert_eq "$rc" 1 "require_cmds rc"
  assert_grep "definitely-not-a-cmd" "$err"
  assert_grep "also-missing" "$err"
  require_cmds bash sh || fail "present commands must pass"
}

test_roots_from_env_splits_words() {
  _load_util
  local -a roots=()
  AUDIO_UTILS_ROOTS="/a /b" audio_utils_roots_from_env roots \
    || fail "roots env not honored"
  assert_eq "${#roots[@]}" 2
  assert_eq "${roots[0]}" "/a"

  unset AUDIO_UTILS_ROOTS WAV2FLAC_ROOTS 2>/dev/null || true
  local rc=0
  audio_utils_roots_from_env roots || rc=$?
  assert_eq "$rc" 1 "empty env must return 1"
}

test_resolve_roots_prefers_args_over_env() {
  _load_util
  local -a roots=()
  AUDIO_UTILS_ROOTS="/env" audio_utils_resolve_roots roots /arg1 /arg2
  assert_eq "${#roots[@]}" 2
  assert_eq "${roots[0]}" "/arg1"

  unset AUDIO_UTILS_ROOTS WAV2FLAC_ROOTS 2>/dev/null || true
  local rc=0
  audio_utils_resolve_roots roots 2>/dev/null || rc=$?
  assert_eq "$rc" 2 "no roots anywhere → 2"
}

test_find_named_dirs_case_insensitive() {
  _load_util
  mkdir -p "$T/lib1/Album/CD1" "$T/lib1/other/cd1" "$T/lib2/CD1"
  local out
  out=$(find_named_dirs cd1 "$T/lib1" "$T/lib2")
  assert_eq "$(wc -l <<<"$out")" 3 "all CD1 variants found"
  assert_grep "Album/CD1" "$out"
}

# --- log.sh escaping ------------------------------------------------------------

test_csv_escape_doubles_quotes() {
  _load_log_helpers
  assert_eq "$(csv_escape 'plain')" '"plain"'
  assert_eq "$(csv_escape 'say "hi"')" '"say ""hi"""'
}

test_json_str_escapes_specials() {
  _load_log_helpers
  assert_eq "$(json_str 'plain')" '"plain"'
  assert_eq "$(json_str 'a"b')" '"a\"b"'
  assert_eq "$(json_str 'a\b')" '"a\\b"'
  assert_eq "$(json_str $'a\nb')" '"a\nb"'
  assert_eq "$(json_str $'a\tb')" '"a\tb"'
}

test_append_locked_appends_and_restricts_mode() {
  require_cmd flock
  _load_log_helpers
  append_locked "$T/log.txt" '%s\n' one
  append_locked "$T/log.txt" '%s,%s\n' two three
  assert_eq "$(cat "$T/log.txt")" $'one\ntwo,three'
  assert_eq "$(stat -c %a "$T/log.txt")" 600 "mode 600"
}

run_tests
