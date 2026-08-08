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

test_state_dir_path_without_home_uses_private_fallback() {
  _load_lib
  local out expected="$T/tmp/audio-utils-${EUID}/state/mytool"
  out=$(unset HOME XDG_STATE_HOME XDG_CACHE_HOME; TMPDIR="$T/tmp" \
    audio_utils_state_dir_path mytool)
  assert_eq "$out" "$expected"
  assert_no_file "$T/tmp/audio-utils-${EUID}" "path lookup must remain lazy"
}

test_state_dir_creates_directory() {
  _load_lib
  export XDG_STATE_HOME="$T/state"
  local d
  d=$(audio_utils_state_dir mytool)
  [[ -d "$d" ]] || fail "state dir not created: $d"
  assert_eq "$d" "$XDG_STATE_HOME/audio-utils/mytool"
}

test_state_and_cache_reject_unsafe_namespaces() {
  _load_lib
  local name fn rc
  for fn in audio_utils_state_dir_path audio_utils_state_dir audio_utils_cache_dir; do
    for name in '../escape' 'nested/tool' '/absolute' '.hidden' '-option' \
      'has space' $'line\nfeed'; do
      rc=0
      "$fn" "$name" >"$T/out" 2>"$T/err" || rc=$?
      assert_eq "$rc" 2 "$fn accepted unsafe namespace"
      assert_grep "invalid audio-utils namespace" "$T/err"
    done
  done
  assert_no_file "$T/escape" "namespace traversal created a path"
}

test_state_and_cache_accept_tool_name_components() {
  _load_lib
  local state cache
  state=$(audio_utils_state_dir_path flac-verify)
  cache=$(audio_utils_cache_dir tool_1.2)
  assert_eq "$state" "$XDG_STATE_HOME/audio-utils/flac-verify"
  assert_eq "$cache" "$XDG_CACHE_HOME/audio-utils/tool_1.2"
  [[ -d "$cache" ]] || fail "cache directory not created"
}

test_state_dir_falls_back_to_cache_when_unwritable() {
  # chmod cannot revoke root's write access (e.g. plain docker runs).
  [[ "$EUID" -ne 0 ]] || skip "running as root; unwritable dirs impossible"
  _load_lib
  export XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache"
  mkdir -p "$XDG_STATE_HOME"
  chmod 500 "$XDG_STATE_HOME"
  local d
  d=$(audio_utils_state_dir mytool) || { chmod 700 "$XDG_STATE_HOME"; fail "no fallback"; }
  chmod 700 "$XDG_STATE_HOME"
  assert_eq "$d" "$XDG_CACHE_HOME/audio-utils/state/mytool"
}

test_state_and_cache_tmp_fallbacks_are_private() {
  _load_lib
  mkdir -p "$T/tmp"
  local state cache root="$T/tmp/audio-utils-${EUID}" mode
  state=$(XDG_STATE_HOME="/proc/audio-utils-test-state" \
    XDG_CACHE_HOME="/proc/audio-utils-test-cache" TMPDIR="$T/tmp" \
    audio_utils_state_dir mytool)
  cache=$(XDG_CACHE_HOME="/proc/audio-utils-test-cache" TMPDIR="$T/tmp" \
    audio_utils_cache_dir mytool)

  assert_eq "$state" "$root/state/mytool"
  assert_eq "$cache" "$root/cache/mytool"
  for mode in "$root" "$state" "$cache"; do
    assert_eq "$(stat -c %a -- "$mode")" 700 "$mode must be private"
  done
}

test_state_and_cache_reject_symlink_fallback_root() {
  _load_lib
  mkdir -p "$T/attacker" "$T/tmp"
  ln -s -- "$T/attacker" "$T/tmp/audio-utils-${EUID}"
  local fn
  for fn in audio_utils_state_dir audio_utils_cache_dir; do
    if XDG_STATE_HOME="/proc/audio-utils-test-state" \
      XDG_CACHE_HOME="/proc/audio-utils-test-cache" TMPDIR="$T/tmp" \
      "$fn" mytool >"$T/out" 2>/dev/null; then
      fail "$fn accepted a symlinked fallback root"
    fi
  done
  [[ -L "$T/tmp/audio-utils-${EUID}" ]] || fail "fallback symlink changed"
  assert_eq "$(find "$T/attacker" -mindepth 1 -print -quit)" "" \
    "symlink target must remain untouched"
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

test_mktemp_helpers_reject_unsafe_templates() {
  _load_lib
  local fn template rc
  for fn in audio_utils_mktemp audio_utils_mktemp_d; do
    for template in '../escape.XXXXXX' 'nested/file.XXXXXX' '/absolute.XXXXXX' \
      '-option.XXXXXX' '.hidden.XXXXXX' 'missing-xs' 'only.XX' \
      $'line\nfeed.XXXXXX'; do
      rc=0
      "$fn" "$template" >"$T/out" 2>"$T/err" || rc=$?
      assert_eq "$rc" 2 "$fn accepted unsafe template"
      assert_grep "invalid temporary-file template" "$T/err"
    done
  done
  assert_no_file "$T/escape.XXXXXX" "template traversal created a file"
}

test_mktemp_directory_lands_in_runtime_dir() {
  _load_lib
  local dir
  dir=$(audio_utils_mktemp_d build.XXX)
  [[ -d "$dir" ]] || fail "temporary directory not created: $dir"
  case "$dir" in
    "$XDG_RUNTIME_DIR/audio-utils/build."*) : ;;
    *) fail "temporary directory outside runtime dir: $dir" ;;
  esac
}

test_runtime_dir_rejects_symlink_candidates() {
  _load_lib
  mkdir -p "$T/attacker" "$T/runtime" "$T/cache/audio-utils"
  ln -s -- "$T/attacker" "$T/runtime/audio-utils"
  ln -s -- "$T/attacker" "$T/cache/audio-utils/runtime"

  local out mode
  out=$(XDG_RUNTIME_DIR="$T/runtime" XDG_CACHE_HOME="$T/cache" TMPDIR="$T/tmp" \
    audio_utils_runtime_dir)

  assert_eq "$out" "$T/tmp/audio-utils-runtime-${EUID}"
  [[ ! -e "$T/attacker/tmp.XXXXXX" ]] || fail "symlink candidate was used"
  mode=$(stat -c %a -- "$out")
  assert_eq "$mode" 700 "fallback runtime directory must be private"
}

test_runtime_dir_rejects_symlink_fallback() {
  _load_lib
  mkdir -p "$T/attacker" "$T/tmp"
  ln -s -- "$T/attacker" "$T/tmp/audio-utils-runtime-${EUID}"

  if XDG_RUNTIME_DIR="/proc/audio-utils-test-runtime" \
    XDG_CACHE_HOME="/proc/audio-utils-test-cache" TMPDIR="$T/tmp" \
    audio_utils_runtime_dir >"$T/out" 2>/dev/null; then
    fail "symlink fallback was accepted"
  fi
  [[ -L "$T/tmp/audio-utils-runtime-${EUID}" ]] || fail "fallback symlink changed"
}

run_tests
