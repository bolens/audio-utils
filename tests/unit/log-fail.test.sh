#!/usr/bin/env bash
# Unit tests: lib/core/log.sh failure logging (TSV + JSONL) and
# lib/core/disk.sh free-space preflight.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load() {
  # Stub the probe/xdg dependencies log.sh and disk.sh call into.
  audio_codec() { echo mp3; }
  audio_samples() { echo 88200; }
  file_bytes() { stat -c%s -- "$1" 2>/dev/null || echo 0; }
  audio_utils_ensure_log_file() { : >"$1"; }
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/log.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/disk.sh"
  DRY_RUN=0 QUIET=0 VERBOSE=0
}

test_init_fail_log_writes_tsv_header() {
  require_cmd flock
  _load
  FAIL_LOG="$T/fails.log"
  init_fail_log 2>/dev/null
  assert_grep $'timestamp\tpath\treason' "$FAIL_LOG"
}

test_init_fail_log_jsonl_has_no_header() {
  require_cmd flock
  _load
  FAIL_LOG="$T/fails.jsonl"
  init_fail_log 2>/dev/null
  [[ ! -s "$FAIL_LOG" ]] || fail "jsonl log must start empty"
}

test_log_fail_appends_tsv_row_and_prints_stderr_block() {
  require_cmd flock
  _load
  FAIL_LOG="$T/fails.log"
  init_fail_log 2>/dev/null
  printf 'x' >"$T/bad.mp3"

  local err
  err=$(log_fail "$T/bad.mp3" "decode failed" "exit 1" 2>&1)
  assert_grep "FAIL " "$err"
  assert_grep "reason:   decode failed" "$err"
  assert_grep "codec=mp3" "$err"

  local row
  row=$(tail -1 "$FAIL_LOG")
  assert_grep $'bad.mp3\tdecode failed\texit 1\tmp3\t1\t88200' "$row"
}

test_log_fail_jsonl_row_is_valid_json() {
  require_cmd flock
  _load
  FAIL_LOG="$T/fails.jsonl"
  init_fail_log 2>/dev/null
  printf 'x' >"$T/bad.mp3"

  log_fail "$T/bad.mp3" 'reason with "quotes"' $'detail\nline2' 2>/dev/null
  assert_eq "$(wc -l <"$FAIL_LOG")" 1 "one row"
  assert_grep '"reason":"reason with \\"quotes\\""' "$FAIL_LOG"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.loads(open(sys.argv[1]).readline())' \
      "$FAIL_LOG" || fail "invalid JSON row"
  fi
}

test_log_fail_merges_stashed_stderr_into_detail() {
  require_cmd flock
  _load
  FAIL_LOG="$T/fails.log"
  init_fail_log 2>/dev/null
  printf 'x' >"$T/bad.mp3"
  printf 'encoder exploded\nsecond line\n' >"$T/tool.err"
  set_last_err_file "$T/tool.err"

  log_fail "$T/bad.mp3" "encode failed" "rc=1" 2>/dev/null
  assert_grep "rc=1 | encoder exploded second line" "$(tail -1 "$FAIL_LOG")"
  # Stash must be one-shot.
  assert_eq "${AUDIO_UTILS_LAST_ERR:-}" "" "last-err cleared after use"
}

test_dry_run_suppresses_fail_log_writes() {
  require_cmd flock
  _load
  FAIL_LOG="$T/fails.log"
  init_fail_log 2>/dev/null
  DRY_RUN=1
  printf 'x' >"$T/bad.mp3"
  log_fail "$T/bad.mp3" "boom" 2>/dev/null
  assert_eq "$(grep -c "boom" "$FAIL_LOG" || true)" 0 "dry run must not append"
}

# --- disk.sh --------------------------------------------------------------------

test_disk_preflight_passes_with_space() {
  _load
  printf '12345' >"$T/src.wav"
  check_disk_space "$T" "$T/src.wav" || fail "tiny file must fit"
}

test_disk_preflight_fails_when_factor_exceeds_free() {
  _load
  printf '12345' >"$T/src.wav"
  # Fake a nearly-full disk.
  au_bytes_avail() { echo 10; }
  local rc=0 err
  err=$(check_disk_space "$T" "$T/src.wav" 2>&1) || rc=$?
  assert_eq "$rc" 1 "must fail on insufficient space"
  assert_grep "insufficient free space" "$err"
}

test_disk_preflight_uses_largest_file_and_factor() {
  _load
  printf '1234567890' >"$T/big.wav"   # 10 bytes
  printf '12' >"$T/small.wav"
  au_bytes_avail() { echo 24; }
  # factor 2 → need 20 ≤ 24 free: ok
  CHECK_DISK_FACTOR=2 check_disk_space "$T" "$T/small.wav" "$T/big.wav" \
    || fail "20 needed, 24 free must pass"
  # factor 3 → need 30 > 24 free: fail
  local rc=0
  CHECK_DISK_FACTOR=3 check_disk_space "$T" "$T/small.wav" "$T/big.wav" \
    2>/dev/null || rc=$?
  assert_eq "$rc" 1 "30 needed, 24 free must fail"
}

run_tests
