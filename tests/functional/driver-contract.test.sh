#!/usr/bin/env bash
# Functional: shared driver CLI contract, exercised through flac-verify
# (read-only, logs one success row per file). Covers -f lists, stdin dirs,
# CSV vs JSONL success logs, -L, bad -j, and default XDG state-dir logs.
# covers: lib/cli/driver.sh lib/cli/worker.sh lib/core/success_log.sh
# covers: lib/core/progress.sh lib/core/version.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
# shellcheck source=../fixtures.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures.sh"

_TOOL=util/flac/flac-verify/flac-verify.sh

_setup_album() { # copies the 3-track album fixture into $T/album
  local src
  src=$(fixture album)
  mkdir -p "$T/album"
  cp "$src/album/"*.flac "$T/album/"
}

test_dir_file_list_with_comments_and_blanks() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  mkdir -p "$T/second"
  cp "$T/album/01 - Track One.flac" "$T/second/solo.flac"

  {
    echo "# comment line"
    echo ""
    echo "$T/album"
    echo "$T/second"
  } >"$T/dirs.txt"

  run_tool "$_TOOL" -j 1 -f "$T/dirs.txt" -S "$T/success.csv"
  assert_eq "$(tool_rc)" 0 "rc ($(tool_out | tail -3))"
  # Header + 4 files (3 album + 1 second).
  assert_eq "$(wc -l <"$T/success.csv")" 5 "csv line count"
  assert_grep "solo.flac" "$T/success.csv"
}

test_missing_dir_file_exits_two() {
  require_cmd flac flock
  run_tool "$_TOOL" -f "$T/nope.txt"
  assert_eq "$(tool_rc)" 2 "missing -f file"
  assert_grep "file not found" "$T/out"
}

test_dirs_from_stdin() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  local rc=0
  printf '%s\n' "$T/album" \
    | "$AU_REPO_ROOT/$_TOOL" -j 1 -S "$T/success.csv" >"$T/out" 2>&1 || rc=$?
  assert_eq "$rc" 0 "stdin dirs rc ($(tail -3 "$T/out"))"
  assert_eq "$(wc -l <"$T/success.csv")" 4 "csv rows: header + 3"
}

test_success_csv_header_matches_columns() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  run_tool "$_TOOL" -j 1 -S "$T/success.csv" "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_eq "$(head -1 "$T/success.csv")" \
    "timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes" \
    "csv header"
  # Every data row has the full column count (9 → 8 commas).
  local bad
  bad=$(tail -n +2 "$T/success.csv" | awk -F, 'NF != 9' | wc -l)
  assert_eq "$bad" 0 "csv rows with wrong field count"
}

test_success_jsonl_rows_are_json_objects() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  run_tool "$_TOOL" -j 1 -S "$T/success.jsonl" "$T/album"
  assert_eq "$(tool_rc)" 0
  # No header line in JSONL mode; 3 rows, each a JSON object with ts + flac.
  assert_eq "$(wc -l <"$T/success.jsonl")" 3 "jsonl row count"
  local bad
  bad=$(grep -vc '^{"ts":".*"flac":' "$T/success.jsonl" || true)
  assert_eq "$bad" 0 "jsonl rows missing ts/flac keys"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
for line in open(sys.argv[1]):
    json.loads(line)
' "$T/success.jsonl" || fail "jsonl rows are not valid JSON"
  fi
}

test_custom_fail_log_receives_failures() {
  require_cmd flac flock ffmpeg metaflac
  local src
  src=$(fixture flac_corrupt)
  mkdir -p "$T/album"
  cp "$src/corrupt.flac" "$T/album/"

  run_tool "$_TOOL" -j 1 -L "$T/fails.log" "$T/album"
  assert_eq "$(tool_rc)" 1 "corrupt flac must fail"
  assert_grep "corrupt.flac" "$T/fails.log"
}

test_invalid_jobs_value_exits_two() {
  require_cmd flac flock
  _setup_album
  run_tool "$_TOOL" -j 0 "$T/album"
  assert_eq "$(tool_rc)" 2 "-j 0"
  run_tool "$_TOOL" -j abc "$T/album"
  assert_eq "$(tool_rc)" 2 "-j abc"
}

test_parallel_jobs_process_all_files() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  run_tool "$_TOOL" -j 4 -S "$T/success.csv" "$T/album"
  assert_eq "$(tool_rc)" 0 "parallel rc"
  assert_eq "$(tail -n +2 "$T/success.csv" | wc -l)" 3 "all 3 files verified"
}

test_default_logs_land_in_state_dir() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  export XDG_STATE_HOME="$T/state"
  run_tool "$_TOOL" -j 1 "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_file "$T/state/audio-utils/flac-verify/failures.log" "default fail log"
  assert_file "$T/state/audio-utils/flac-verify/success.csv" "default success log"
}

test_quiet_plus_verbose_prefers_verbose() {
  require_cmd flac flock ffmpeg metaflac
  _setup_album
  run_tool "$_TOOL" -j 1 -q -v "$T/album"
  assert_eq "$(tool_rc)" 0
  assert_grep "using verbose" "$T/out"
}

test_version_flag() {
  require_cmd flac flock
  run_tool "$_TOOL" --version
  assert_eq "$(tool_rc)" 0 "--version rc"
  assert_grep "flac-verify" "$T/out"
}

run_tests
