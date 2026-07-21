#!/usr/bin/env bash
# Test harness — source from tests/**/*.test.sh, define test_* functions,
# then call run_tests at the end of the file.
#
# Each test_* function runs in a subshell with its own scratch dir ($T).
# Result protocol per function: return 0 = pass, non-zero = fail,
# exit AU_TEST_SKIP_RC (75) = skip (use the skip/require_cmd helpers).
#
# Output is TAP-style: "ok NAME", "not ok NAME", "ok NAME # SKIP reason".

set -u

AU_TEST_SKIP_RC=75

# Repo root (tests/ parent) — exported by run.sh; derive when run directly.
if [[ -z "${AU_REPO_ROOT:-}" ]]; then
  AU_REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  export AU_REPO_ROOT
fi

# Sandbox for direct (non-run.sh) invocation, so stray runs never touch
# the real HOME / XDG dirs.
if [[ -z "${AU_TEST_SANDBOX:-}" ]]; then
  AU_TEST_SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/au-test.XXXXXX")
  export AU_TEST_SANDBOX
  # shellcheck disable=SC2064  # expand now: sandbox path is fixed
  trap "rm -rf -- '$AU_TEST_SANDBOX'" EXIT
  mkdir -p "$AU_TEST_SANDBOX"/{home,state,cache,config,runtime,tmp}
  chmod 700 "$AU_TEST_SANDBOX/runtime"
  export HOME="$AU_TEST_SANDBOX/home"
  export XDG_STATE_HOME="$AU_TEST_SANDBOX/state"
  export XDG_CACHE_HOME="$AU_TEST_SANDBOX/cache"
  export XDG_CONFIG_HOME="$AU_TEST_SANDBOX/config"
  export XDG_RUNTIME_DIR="$AU_TEST_SANDBOX/runtime"
  export TMPDIR="$AU_TEST_SANDBOX/tmp"
fi

_AU_TEST_FILE="${BASH_SOURCE[1]:-unknown}"
_AU_PASS=0
_AU_FAIL=0
_AU_SKIP=0

# --- helpers usable inside test functions -----------------------------------

skip() {
  echo "SKIP: ${*:-}" >&2
  exit "$AU_TEST_SKIP_RC"
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || skip "missing dependency: $c"
  done
}

fail() {
  echo "FAIL: ${*:-}" >&2
  return 1
}

assert_eq() { # actual expected [label]
  if [[ "$1" != "$2" ]]; then
    fail "${3:-assert_eq}: expected '$2', got '$1'"
  fi
}

assert_exit() { # expected_rc command [args...]
  local expected=$1 rc=0
  shift
  "$@" || rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    fail "assert_exit: '$*' exited $rc, expected $expected"
  fi
}

assert_file() { # path [label]
  [[ -f "$1" ]] || fail "${2:-assert_file}: missing file: $1"
}

assert_no_file() { # path [label]
  [[ ! -e "$1" ]] || fail "${2:-assert_no_file}: unexpected file: $1"
}

assert_grep() { # pattern file_or_string_flag...
  local pattern=$1 target=$2
  if [[ -f "$target" ]]; then
    grep -q -- "$pattern" "$target" || \
      fail "assert_grep: pattern '$pattern' not found in file $target"
  else
    printf '%s\n' "$target" | grep -q -- "$pattern" || \
      fail "assert_grep: pattern '$pattern' not found in string"
  fi
}

assert_not_grep() { # pattern file_or_string
  local pattern=$1 target=$2
  if [[ -f "$target" ]]; then
    ! grep -q -- "$pattern" "$target" || \
      fail "assert_not_grep: pattern '$pattern' found in file $target"
  else
    ! printf '%s\n' "$target" | grep -q -- "$pattern" || \
      fail "assert_not_grep: pattern '$pattern' found in string"
  fi
}

require_ffmpeg_encoder() {
  require_cmd ffmpeg
  # Capture first: grep -q on a live pipe SIGPIPEs ffmpeg → pipefail failure.
  local encoders
  encoders=$(ffmpeg -hide_banner -v error -encoders 2>/dev/null) || true
  grep -q " $1 " <<<"$encoders" || skip "ffmpeg lacks encoder: $1"
}

# Container-level tag via ffprobe (case-insensitive tag name).
ffprobe_tag() { # file tag
  ffprobe -v error -show_entries "format_tags=$2" \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

# Decoded-PCM MD5 of an audio file (container/tag independent).
audio_md5() {
  ffmpeg -nostdin -v error -i "$1" -map 0:a:0 -f md5 - 2>/dev/null | sed 's/^MD5=//'
}

assert_audio_md5_eq() { # file_a file_b
  require_cmd ffmpeg
  local a b
  a=$(audio_md5 "$1") || fail "audio_md5 failed for $1"
  b=$(audio_md5 "$2") || fail "audio_md5 failed for $2"
  [[ -n "$a" && "$a" == "$b" ]] || \
    fail "assert_audio_md5_eq: $1 ($a) != $2 ($b)"
}

# Run a tool entry script, capturing stdout+stderr to $T/out and rc to $T/rc.
# Usage: run_tool <path-relative-to-repo-root> [args...]
# stdin is /dev/null so the driver does not read DIRs from a non-tty stdin.
# (Not <&-: with fd 0 closed, the next open() lands on fd 0 and ffmpeg 6.1's
# console handler reads it, silently truncating decodes.)
run_tool() {
  local tool="$AU_REPO_ROOT/$1"
  shift
  local rc=0
  "$tool" "$@" >"$T/out" 2>&1 </dev/null || rc=$?
  echo "$rc" >"$T/rc"
  return 0
}

tool_rc() { cat "$T/rc"; }
tool_out() { cat "$T/out"; }

# --- runner ------------------------------------------------------------------

run_tests() {
  local fn rc t_dir
  local -a fns=()
  mapfile -t fns < <(declare -F | awk '$3 ~ /^test_/ { print $3 }')

  if ((${#fns[@]} == 0)); then
    echo "not ok ${_AU_TEST_FILE} # no test_* functions found"
    exit 1
  fi

  for fn in "${fns[@]}"; do
    if [[ -n "${AU_TEST_FILTER:-}" && "$fn" != *${AU_TEST_FILTER}* ]]; then
      continue
    fi
    t_dir=$(mktemp -d "${TMPDIR:-/tmp}/${fn}.XXXXXX")
    rc=0
    (
      set -e
      cd "$t_dir"
      T="$t_dir"
      export T
      "$fn"
    ) >"$t_dir/.test-output" 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      echo "ok $fn"
      ((++_AU_PASS))
    elif [[ "$rc" -eq "$AU_TEST_SKIP_RC" ]]; then
      echo "ok $fn # SKIP $(grep -m1 '^SKIP:' "$t_dir/.test-output" 2>/dev/null | cut -c7- || true)"
      ((++_AU_SKIP))
    else
      echo "not ok $fn"
      sed 's/^/#   /' "$t_dir/.test-output"
      ((++_AU_FAIL))
    fi
    rm -rf -- "$t_dir"
  done

  echo "# ${_AU_TEST_FILE##*/}: pass=$_AU_PASS fail=$_AU_FAIL skip=$_AU_SKIP"
  [[ "$_AU_FAIL" -eq 0 ]]
}
