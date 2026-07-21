#!/usr/bin/env bash
# Unit tests: lib/core/xdg.sh (state/cache/runtime path resolution).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_lib() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/xdg.sh"
}

test_state_dir_path_uses_xdg_state_home() {
  _load_lib
  assert_eq "$(audio_utils_state_dir_path mytool)" \
    "$XDG_STATE_HOME/audio-utils/mytool"
}

test_state_dir_path_falls_back_to_home() {
  _load_lib
  local out
  out=$(unset XDG_STATE_HOME; audio_utils_state_dir_path mytool)
  assert_eq "$out" "$HOME/.local/state/audio-utils/mytool"
}

test_state_dir_path_is_lazy() {
  _load_lib
  export XDG_STATE_HOME="$T/state"
  audio_utils_state_dir_path mytool >/dev/null
  assert_no_file "$XDG_STATE_HOME/audio-utils/mytool" "must not create dirs"
}

test_state_dir_creates_directory() {
  _load_lib
  export XDG_STATE_HOME="$T/state"
  local d
  d=$(audio_utils_state_dir mytool)
  [[ -d "$d" ]] || fail "state dir not created: $d"
  assert_eq "$d" "$XDG_STATE_HOME/audio-utils/mytool"
}

test_state_dir_falls_back_to_cache_when_unwritable() {
  _load_lib
  export XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache"
  mkdir -p "$XDG_STATE_HOME"
  chmod 500 "$XDG_STATE_HOME"
  local d
  d=$(audio_utils_state_dir mytool) || { chmod 700 "$XDG_STATE_HOME"; fail "no fallback"; }
  chmod 700 "$XDG_STATE_HOME"
  assert_eq "$d" "$XDG_CACHE_HOME/audio-utils/state/mytool"
}

test_ensure_log_file_creates_with_0600() {
  _load_lib
  local f="$T/logs/sub/test.log" mode
  audio_utils_ensure_log_file "$f"
  assert_file "$f"
  mode=$(stat -c %a "$f")
  assert_eq "$mode" "600"
}

test_ensure_log_file_truncate() {
  _load_lib
  local f="$T/test.log"
  echo data >"$f"
  audio_utils_ensure_log_file "$f" truncate
  assert_eq "$(wc -c <"$f")" "0" "file must be truncated"
}

test_mktemp_lands_in_runtime_dir() {
  _load_lib
  local f
  f=$(audio_utils_mktemp probe.XXXXXX)
  assert_file "$f"
  case "$f" in
    "$XDG_RUNTIME_DIR/audio-utils/"*) : ;;
    *) fail "mktemp outside runtime dir: $f" ;;
  esac
}

run_tests
