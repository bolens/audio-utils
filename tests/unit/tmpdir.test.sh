#!/usr/bin/env bash
# Unit tests: lib/core/tmpdir.sh workdir registry and orphan sweeps.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load() {
  QUIET=0 VERBOSE=0
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/compat.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/log.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/xdg.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/tmpdir.sh"
}

test_make_workdir_lands_beside_dest() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/album"
  local wd
  wd=$(make_workdir "$T/album")
  [[ -d "$wd" ]] || fail "workdir not created"
  assert_eq "$(dirname "$wd")" "$T/album" "same dir as dest (atomic mv)"
  assert_grep "/.audio-utils." "$wd"
  cleanup_registered_tmpdirs
}

test_workdir_prefix_env_honored() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/album"
  local wd
  wd=$(AUDIO_UTILS_WORKDIR_PREFIX=mytool make_workdir "$T/album")
  assert_grep "/.mytool." "$wd"
  cleanup_registered_tmpdirs
}

test_workdir_prefix_rejects_path_fragments() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/album" "$T/runtime-parent"
  local prefix rc
  for prefix in '../escape' 'bad/name' '.hidden' 'has space' '-option'; do
    rc=0
    AUDIO_UTILS_WORKDIR_PREFIX=$prefix make_workdir "$T/album" \
      >"$T/out" 2>"$T/err" || rc=$?
    assert_eq "$rc" 2 "reject prefix: $prefix"
  done
  assert_not_grep '/escape\.' "$(find "$T" -mindepth 1 -print)"
}

test_invalid_prefix_prevents_orphan_sweep() {
  _load
  mkdir -p "$T/album/.audio-utils.keep"
  _invalid_sweep() {
    AUDIO_UTILS_WORKDIR_PREFIX='../escape' sweep_orphan_workdirs "$T/album"
  }
  assert_exit 2 _invalid_sweep
  [[ -d "$T/album/.audio-utils.keep" ]] || fail "invalid prefix triggered deletion"
}

test_cleanup_removes_registered_dirs_only() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/album"
  local wd
  wd=$(make_workdir "$T/album")
  mkdir -p "$T/album/keep-me"

  cleanup_registered_tmpdirs
  [[ ! -d "$wd" ]] || fail "registered workdir must be removed"
  assert_file "$T/album/keep-me/../keep-me/." 2>/dev/null || [[ -d "$T/album/keep-me" ]] \
    || fail "unregistered dir must survive"
}

test_cleanup_rejects_unsafe_registered_directory() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/library"
  printf '%s\n' "$T/library" >"$AUDIO_UTILS_TMP_REGISTRY/unsafe"
  assert_exit 1 cleanup_registered_tmpdirs
  [[ -d "$T/library" ]] || fail "unsafe registered directory was removed"
}

test_cleanup_rejects_workdir_like_name_with_wrong_suffix() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/.audio-utils.library"
  printf '%s\n' "$T/.audio-utils.library" >"$AUDIO_UTILS_TMP_REGISTRY/unsafe"
  assert_exit 1 cleanup_registered_tmpdirs
  [[ -d "$T/.audio-utils.library" ]] || fail "non-workdir dot directory was removed"
}

test_unregister_protects_dir_from_cleanup() {
  _load
  init_tmpdir_registry
  mkdir -p "$T/album"
  local wd
  wd=$(make_workdir "$T/album")
  unregister_tmpdir "$wd"
  cleanup_registered_tmpdirs
  [[ -d "$wd" ]] || fail "unregistered workdir must not be swept"
}

test_sweep_orphan_workdirs_matches_prefix_only() {
  _load
  mkdir -p "$T/album/.audio-utils.AbC123" "$T/album/.audio-utils.archive" \
    "$T/album/.audio-utils.!!!!!!" \
    "$T/album/.other.XYZ123" "$T/album/normal"
  sweep_orphan_workdirs "$T/album" 2>/dev/null
  [[ ! -d "$T/album/.audio-utils.AbC123" ]] || fail "orphan not swept"
  [[ -d "$T/album/.audio-utils.archive" ]] || fail "non-workdir dotdir must survive"
  [[ -d "$T/album/.audio-utils.!!!!!!" ]] || fail "invalid suffix must survive"
  [[ -d "$T/album/.other.XYZ123" ]] || fail "foreign dotdir must survive"
  [[ -d "$T/album/normal" ]] || fail "normal dir must survive"
}

test_sweep_orphan_workdirs_never_removes_scan_root() {
  _load
  mkdir -p "$T/.audio-utils.root/.audio-utils.AbC123"
  sweep_orphan_workdirs "$T/.audio-utils.root" 2>/dev/null
  [[ -d "$T/.audio-utils.root" ]] || fail "scan root was removed"
  [[ ! -d "$T/.audio-utils.root/.audio-utils.AbC123" ]] || fail "child orphan not swept"
}

test_sweep_orphans_in_roots_recursive() {
  _load
  mkdir -p "$T/lib/a/.audio-utils.AbC123" "$T/lib/b/deep/.audio-utils.XyZ789"
  sweep_orphans_in_roots "$T/lib" 2>/dev/null
  [[ ! -d "$T/lib/a/.audio-utils.AbC123" ]] || fail "root-level orphan not swept"
  [[ ! -d "$T/lib/b/deep/.audio-utils.XyZ789" ]] || fail "nested orphan not swept"
}

test_sweep_orphans_in_roots_never_removes_library_root() {
  _load
  mkdir -p "$T/.audio-utils.library/a/.audio-utils.AbC123"
  sweep_orphans_in_roots "$T/.audio-utils.library" 2>/dev/null
  [[ -d "$T/.audio-utils.library" ]] || fail "library root was removed"
  [[ ! -d "$T/.audio-utils.library/a/.audio-utils.AbC123" ]] || \
    fail "nested orphan not swept"
}

run_tests
