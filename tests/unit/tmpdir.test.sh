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
  mkdir -p "$T/album/.audio-utils.AbC123" "$T/album/.other.XYZ" "$T/album/normal"
  sweep_orphan_workdirs "$T/album" 2>/dev/null
  [[ ! -d "$T/album/.audio-utils.AbC123" ]] || fail "orphan not swept"
  [[ -d "$T/album/.other.XYZ" ]] || fail "foreign dotdir must survive"
  [[ -d "$T/album/normal" ]] || fail "normal dir must survive"
}

test_sweep_orphans_in_roots_recursive() {
  _load
  mkdir -p "$T/lib/a/.audio-utils.one" "$T/lib/b/deep/.audio-utils.two"
  sweep_orphans_in_roots "$T/lib" 2>/dev/null
  [[ ! -d "$T/lib/a/.audio-utils.one" ]] || fail "root-level orphan not swept"
  [[ ! -d "$T/lib/b/deep/.audio-utils.two" ]] || fail "nested orphan not swept"
}

run_tests
