#!/usr/bin/env bash
# Functional: scripts/ape-codec.sh — install/uninstall/update/status against a
# tiny fake SDK served over file:// (APE_CODEC_URL_BASE test hook). Covers
# hash pinning/rejection, manifest integrity, permission checks, zip-slip
# refusal, and the update flow. Gated on cmake + a C++ toolchain + zip.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_SCRIPT="$AU_REPO_ROOT/scripts/ape-codec.sh"
_FAKE_VER=9999 # unpinned on purpose: exercises the --sha256 requirement

_require_build_deps() {
  require_cmd curl unzip cmake zip sha256sum
  if ! command -v c++ >/dev/null 2>&1 && ! command -v g++ >/dev/null 2>&1 \
    && ! command -v clang++ >/dev/null 2>&1; then
    skip "no C++ compiler"
  fi
}

# Build MAC_9999_SDK.zip: a minimal cmake project whose `mac` target prints
# the same banner shape the real SDK does (the installer sanity-checks it).
_mk_fake_sdk() {
  local d="$T/sdk-src"
  mkdir -p "$d"
  cat >"$d/main.c" <<'EOF'
#include <stdio.h>
int main(void) {
  printf("--- Monkey's Audio Console Front End (v 99.99) Copyright fake ---\n");
  return 255;
}
EOF
  cat >"$d/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.10)
project(fakemac C)
option(BUILD_SHARED "unused" ON)
add_executable(mac main.c)
EOF
  (cd "$d" && zip -q "$T/MAC_${_FAKE_VER}_SDK.zip" main.c CMakeLists.txt)
  sha256sum "$T/MAC_${_FAKE_VER}_SDK.zip" | awk '{print $1}' >"$T/zip.sha"
}

# Run ape-codec.sh sandboxed: private XDG dirs + prefix, file:// URL base.
_ape() { # args...
  local rc=0
  XDG_DATA_HOME="$T/data" XDG_CACHE_HOME="$T/cache" \
    APE_CODEC_URL_BASE="file://$T" \
    APE_CODEC_RELEASES_URL="file://$T/developers.html" \
    bash "$_SCRIPT" "$@" >"$T/out" 2>&1 || rc=$?
  echo "$rc" >"$T/rc"
  return 0
}

_install_ok() {
  _ape install --version "$_FAKE_VER" --prefix "$T/prefix" \
    --sha256 "$(cat "$T/zip.sha")"
}

test_install_verifies_hash_builds_and_sets_perms() {
  _require_build_deps
  _mk_fake_sdk

  _install_ok
  assert_eq "$(cat "$T/rc")" 0 "install rc ($(tail -3 "$T/out"))"
  assert_file "$T/prefix/bin/mac"
  assert_eq "$(stat -c '%a' "$T/prefix/bin/mac")" "755" "binary mode"
  assert_file "$T/data/audio-utils/ape-codec/manifest.tsv"
  assert_eq "$(stat -c '%a' "$T/data/audio-utils/ape-codec/manifest.tsv")" "644" \
    "manifest mode"
  assert_grep "verified download" "$T/out"
  local banner
  banner=$("$T/prefix/bin/mac" 2>/dev/null || true)
  grep -q "Monkey's Audio" <<<"$banner" || fail "installed binary does not run"
}

test_install_refuses_wrong_hash_and_removes_download() {
  _require_build_deps
  _mk_fake_sdk

  _ape install --version "$_FAKE_VER" --prefix "$T/prefix" \
    --sha256 "$(printf '0%.0s' {1..64})"
  assert_eq "$(cat "$T/rc")" 1 "wrong hash must fail"
  assert_grep "SHA-256 mismatch" "$T/out"
  assert_no_file "$T/prefix/bin/mac" "nothing must be installed"
  assert_no_file "$T/cache/audio-utils/ape-codec/MAC_${_FAKE_VER}_SDK.zip" \
    "bad download must be removed"
}

test_install_unpinned_without_sha256_refuses_and_prints_hash() {
  _require_build_deps
  _mk_fake_sdk

  _ape install --version "$_FAKE_VER" --prefix "$T/prefix"
  assert_eq "$(cat "$T/rc")" 1 "unpinned version must require --sha256"
  assert_grep "no pinned hash" "$T/out"
  assert_grep "$(cat "$T/zip.sha")" "$T/out"
  assert_no_file "$T/prefix/bin/mac"
}

test_install_is_idempotent_without_force() {
  _require_build_deps
  _mk_fake_sdk
  _install_ok
  assert_eq "$(cat "$T/rc")" 0

  _install_ok
  assert_eq "$(cat "$T/rc")" 0
  assert_grep "already installed" "$T/out"
}

test_status_reports_intact_and_modified() {
  _require_build_deps
  _mk_fake_sdk
  _install_ok

  _ape status --prefix "$T/prefix"
  assert_eq "$(cat "$T/rc")" 0 "intact status rc"
  assert_grep "installed: yes" "$T/out"
  assert_grep "99.99" "$T/out"
  assert_grep "(ok, 755)" "$T/out"

  printf 'tampered' >>"$T/prefix/bin/mac"
  _ape status --prefix "$T/prefix"
  assert_eq "$(cat "$T/rc")" 1 "modified binary must flip status rc"
  assert_grep "MODIFIED" "$T/out"
}

test_uninstall_removes_intact_files_only() {
  _require_build_deps
  _mk_fake_sdk
  _install_ok

  # Modified binary: refuse without --force…
  printf 'tampered' >>"$T/prefix/bin/mac"
  _ape uninstall --prefix "$T/prefix"
  assert_eq "$(cat "$T/rc")" 1 "modified file must block uninstall"
  assert_grep "was modified since install" "$T/out"
  assert_file "$T/prefix/bin/mac"

  # …and remove with it.
  _ape uninstall --prefix "$T/prefix" --force --purge
  assert_eq "$(cat "$T/rc")" 0 "forced uninstall rc"
  assert_no_file "$T/prefix/bin/mac"
  assert_no_file "$T/data/audio-utils/ape-codec/manifest.tsv"
  [[ ! -d "$T/cache/audio-utils/ape-codec" ]] || fail "--purge must clear cache"
}

test_update_flow_up_to_date_and_upgrade() {
  _require_build_deps
  _mk_fake_sdk
  printf '<a href="files/MAC_%s_SDK.zip">SDK</a>\n' "$_FAKE_VER" \
    >"$T/developers.html"
  _install_ok

  _ape update --prefix "$T/prefix" --sha256 "$(cat "$T/zip.sha")"
  assert_eq "$(cat "$T/rc")" 0
  assert_grep "up to date" "$T/out"

  # Releases page now advertises an older version → still up to date.
  printf '<a href="files/MAC_1000_SDK.zip">SDK</a>\n' >"$T/developers.html"
  _ape update --prefix "$T/prefix"
  assert_eq "$(cat "$T/rc")" 0
  assert_grep "up to date" "$T/out"
}

test_zip_slip_entries_are_refused() {
  _require_build_deps
  command -v python3 >/dev/null 2>&1 || skip "no python3 to craft evil zip"
  python3 - "$T/MAC_${_FAKE_VER}_SDK.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("../evil.txt", "pwned")
    z.writestr("CMakeLists.txt", "")
PY
  sha256sum "$T/MAC_${_FAKE_VER}_SDK.zip" | awk '{print $1}' >"$T/zip.sha"

  _install_ok
  assert_eq "$(cat "$T/rc")" 1 "zip-slip entries must be refused"
  assert_grep "safety check" "$T/out"
  assert_no_file "$T/prefix/bin/mac"
}

test_usage_errors() {
  _ape frobnicate
  assert_eq "$(cat "$T/rc")" 2 "unknown command exits 2"
  _ape install --version not-a-version
  assert_eq "$(cat "$T/rc")" 1 "bad version rejected"
  _ape install --sha256 nothex
  assert_eq "$(cat "$T/rc")" 1 "bad sha256 rejected"
}

run_tests
