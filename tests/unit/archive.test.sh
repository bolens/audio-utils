#!/usr/bin/env bash
# Unit tests: preservation-package parsing, verification, and snapshots.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_archive() {
  log_err() { printf '%s\n' "$*" >&2; }
  au_abspath() { readlink -m -- "$1"; }
  file_sha256() { sha256sum -- "$1" | awk '{print $1}'; }
  file_bytes() { stat -c %s -- "$1"; }
  json_str() {
    local s=$1
    s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}
    printf '"%s"' "$s"
  }
  audio_utils_version() { printf 'test\n'; }
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/media/archive.sh"
}

_write_package_marker() { # dir signed par2 preserved sealed
  local dir=$1 sums
  sums=$(file_sha256 "$dir/SHA256SUMS")
  printf '{"status":"complete","package_id":"pkg","session":"session","completed":"now","sha256sums":"%s","signed":%s,"par2_percent":%s,"preserved_streams":%s,"sealed":%s}\n' \
    "$sums" "$2" "$3" "$4" "$5" >"$dir/ARCHIVE_COMPLETE.json"
}

test_archive_package_verify_accepts_minimal_unsigned_package() {
  _load_archive
  mkdir -p "$T/pkg"
  printf 'audio\n' >"$T/pkg/track.flac"
  (cd "$T/pkg" && sha256sum ./track.flac >SHA256SUMS)
  _write_package_marker "$T/pkg" false 0 false false
  archive_package_verify "$T/pkg"
}

test_archive_package_verify_rejects_traversal_and_marker_mismatch() {
  _load_archive
  mkdir -p "$T/pkg"
  printf '%064d  ./../escape\n' 0 >"$T/pkg/SHA256SUMS"
  _write_package_marker "$T/pkg" false 0 false false
  assert_exit 1 archive_package_verify "$T/pkg"

  printf 'audio\n' >"$T/pkg/track.flac"
  (cd "$T/pkg" && sha256sum ./track.flac >SHA256SUMS)
  _write_package_marker "$T/pkg" false 0 false false
  printf 'changed\n' >>"$T/pkg/SHA256SUMS"
  assert_exit 1 archive_package_verify "$T/pkg"
}

test_archive_package_verify_enforces_unsigned_and_par2_state() {
  _load_archive
  mkdir -p "$T/pkg"
  printf 'audio\n' >"$T/pkg/track.flac"
  (cd "$T/pkg" && sha256sum ./track.flac >SHA256SUMS)
  printf 'unexpected\n' >"$T/pkg/SHA256SUMS.minisig"
  _write_package_marker "$T/pkg" false 0 false false
  assert_exit 1 archive_package_verify "$T/pkg"
  rm "$T/pkg/SHA256SUMS.minisig"
  _write_package_marker "$T/pkg" false 5 false false
  assert_exit 1 archive_package_verify "$T/pkg"
}

test_archive_snapshot_is_deterministic_and_atomic() {
  _load_archive
  mkdir -p "$T/pkg/sub" "$T/snapshots"
  printf 'b\n' >"$T/pkg/sub/b file"
  printf 'a\n' >"$T/pkg/a"
  archive_snapshot_write "$T/pkg" "$T/snapshots/one.jsonl"
  archive_snapshot_write "$T/pkg" "$T/snapshots/two.jsonl"
  cmp -s "$T/snapshots/one.jsonl" "$T/snapshots/two.jsonl" || \
    fail "identical packages produced different snapshots"
  assert_grep '"path":"sub/b file"' "$T/snapshots/one.jsonl"
  if find "$T/snapshots" -name '.archive-snapshot.*' -print -quit | grep -q .; then
    fail "snapshot temporary file leaked"
  fi
}

test_archive_snapshot_rejects_output_inside_package() {
  _load_archive
  mkdir -p "$T/pkg/sub"
  printf 'audio\n' >"$T/pkg/track.flac"
  assert_exit 1 archive_snapshot_write "$T/pkg" "$T/pkg/sub/snapshot.jsonl"
  assert_no_file "$T/pkg/sub/snapshot.jsonl"
}

run_tests
