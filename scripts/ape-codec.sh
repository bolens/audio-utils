#!/usr/bin/env bash
# Manage the Monkey's Audio (APE) codec on Linux, where no official binary
# build exists: download the open-source SDK, verify it, build it statically,
# and install the `mac` encoder/decoder under an XDG-compliant prefix.
#
# Usage:
#   scripts/ape-codec.sh install   [--version V] [--sha256 H] [--force]
#   scripts/ape-codec.sh update    [--sha256 H]
#   scripts/ape-codec.sh uninstall [--force] [--purge]
#   scripts/ape-codec.sh status
#
#   --version V   SDK version, e.g. 13.19 or 1319, or "latest" (default: newest
#                 pinned version)
#   --sha256 H    expected SHA-256 of the SDK zip; required for versions
#                 without a pinned hash
#   --force       install: rebuild/reinstall even if already installed
#                 uninstall: remove files even if they were modified
#   --purge       uninstall: also delete cached downloads
#   --prefix DIR  install prefix (default: ~/.local; binary goes in DIR/bin)
#
# Layout (XDG):
#   binary    -> PREFIX/bin/mac                    (default ~/.local/bin/mac)
#   manifest  -> $XDG_DATA_HOME/audio-utils/ape-codec/manifest.tsv
#   downloads -> $XDG_CACHE_HOME/audio-utils/ape-codec/
#
# Security: downloads are HTTPS-only, verified against a pinned SHA-256 (or an
# explicit --sha256) before extraction, zip entries are checked for path
# escapes, and installed files get explicit 0755/0644 modes. Uninstall only
# removes files whose hashes still match the install manifest.
#
# License: the SDK is (c) Matthew T. Ashland, 3-clause BSD (License.txt in
# the zip; see docs/third-party.md). Nothing from it is bundled in this repo.
#
# Exit codes: 0 ok, 1 failure, 2 usage
set -euo pipefail
umask 022

# Known-good SDK zips: version -> SHA-256. Extend when new releases are vetted.
declare -A APE_PINNED_SHA256=(
  [1319]=88cfc81300ca33513cba48e894ecd89c2e997257da7b29f8411a73251e348340
)
APE_DEFAULT_VERSION=1319

# Overridable for tests (file:// URLs are accepted for these overrides only).
URL_BASE=${APE_CODEC_URL_BASE:-https://monkeysaudio.com/files}
RELEASES_URL=${APE_CODEC_RELEASES_URL:-https://monkeysaudio.com/developers.html}

DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/audio-utils/ape-codec
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/audio-utils/ape-codec
MANIFEST=$DATA_DIR/manifest.tsv

PREFIX=${APE_CODEC_PREFIX:-$HOME/.local}
VERSION=""
SHA256=""
FORCE=0
PURGE=0

usage() {
  sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

die() {
  echo "ape-codec: error: $*" >&2
  exit 1
}

info() { echo "ape-codec: $*"; }
warn() { echo "ape-codec: warning: $*" >&2; }

# "13.19" / "1319" -> "1319"; "latest" passes through.
ver_norm() {
  local v=${1//./}
  [[ "$1" == latest || "$v" =~ ^[0-9]{3,4}$ ]] \
    || die "bad version '$1' (expected e.g. 13.19, 1319, or latest)"
  if [[ "$1" == latest ]]; then printf 'latest'; else printf '%s' "$v"; fi
}

# "1319" -> "13.19" (for banner checks and display).
ver_display() {
  printf '%s.%s' "${1%??}" "${1: -2}"
}

require_cmds() {
  local c missing=()
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  ((${#missing[@]} == 0)) || die "missing required tools: ${missing[*]}"
}

cxx_available() {
  command -v c++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1 \
    || command -v clang++ >/dev/null 2>&1
}

sha256_of() {
  sha256sum -- "$1" | awk '{print $1}'
}

# curl wrapper: HTTPS is enforced for network URLs; file:// is allowed so
# tests can point APE_CODEC_URL_BASE at local fixtures.
fetch() { # url dest
  local url=$1 dest=$2
  case "$url" in
    https://*) curl -fsSL --proto '=https' --tlsv1.2 --max-time 300 -o "$dest" "$url" ;;
    file://*) curl -fsS -o "$dest" "$url" ;;
    *) die "refusing non-https URL: $url" ;;
  esac
}

# Newest version advertised on the releases page (e.g. 1319), empty if
# unreachable or unparsable.
latest_version() {
  local page
  page=$(mktemp "${TMPDIR:-/tmp}/ape-releases.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -f -- '$page'" RETURN
  fetch "$RELEASES_URL" "$page" 2>/dev/null || return 1
  grep -oE 'MAC_[0-9]{3,4}_SDK\.zip' "$page" \
    | grep -oE '[0-9]{3,4}' | sort -n | tail -1
}

# Refuse zips with absolute or parent-escaping entry names before extraction.
zip_entries_safe() { # zipfile
  local bad
  bad=$(unzip -Z1 -- "$1" 2>/dev/null | grep -E '^/|(^|/)\.\.(/|$)' || true)
  [[ -z "$bad" ]] || { warn "unsafe zip entries:"$'\n'"$bad"; return 1; }
}

manifest_get() { # key
  [[ -f "$MANIFEST" ]] || return 1
  awk -F'\t' -v k="$1" '$1 == k { print $2; exit }' "$MANIFEST"
}

installed_binary_intact() {
  local path hash
  while IFS=$'\t' read -r type path hash || [[ -n "${type:-}" ]]; do
    [[ "$type" == file ]] || continue
    [[ -f "$path" && "$(sha256_of "$path")" == "$hash" ]] || return 1
  done <"$MANIFEST"
}

# --- commands ------------------------------------------------------------------

cmd_install() {
  require_cmds curl unzip cmake sha256sum install stat awk
  cxx_available || die "no C++ compiler found (need c++, g++, or clang++)"

  local ver=${VERSION:-$APE_DEFAULT_VERSION}
  if [[ "$ver" == latest ]]; then
    ver=$(latest_version) || die "cannot determine latest version from $RELEASES_URL"
    [[ -n "$ver" ]] || die "no SDK version found at $RELEASES_URL"
  fi
  local disp
  disp=$(ver_display "$ver")

  if [[ -f "$MANIFEST" && "$(manifest_get version)" == "$ver" && "$FORCE" -eq 0 ]] \
    && installed_binary_intact; then
    info "Monkey's Audio $disp already installed (use --force to reinstall)"
    return 0
  fi

  local expected=${SHA256:-${APE_PINNED_SHA256[$ver]:-}}
  local zip="$CACHE_DIR/MAC_${ver}_SDK.zip"
  install -d -m 0755 "$CACHE_DIR"

  if [[ ! -f "$zip" ]]; then
    info "downloading MAC_${ver}_SDK.zip"
    fetch "$URL_BASE/MAC_${ver}_SDK.zip" "$zip.part" \
      || die "download failed: $URL_BASE/MAC_${ver}_SDK.zip"
    mv -f -- "$zip.part" "$zip"
  fi
  chmod 0644 "$zip"

  local actual
  actual=$(sha256_of "$zip")
  if [[ -z "$expected" ]]; then
    rm -f -- "$zip"
    die "no pinned hash for version $disp.
  Downloaded zip SHA-256: $actual
  Verify it out-of-band (e.g. against https://monkeysaudio.com), then re-run:
    $0 install --version $disp --sha256 $actual"
  fi
  if [[ "$actual" != "$expected" ]]; then
    rm -f -- "$zip"
    die "SHA-256 mismatch for MAC_${ver}_SDK.zip
  expected: $expected
  actual:   $actual
  The download was removed; retry, and if this persists treat it as suspect."
  fi
  info "verified download (sha256 ok)"

  zip_entries_safe "$zip" || die "zip failed safety check; not extracting"

  local work
  work=$(mktemp -d "$CACHE_DIR/build.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -rf -- '$work'" EXIT

  unzip -q -- "$zip" -d "$work/src"
  info "building (static, release)"
  cmake -S "$work/src" -B "$work/build" -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED=OFF >"$work/cmake.log" 2>&1 \
    || die "cmake configure failed (log: $work/cmake.log)"
  # No --target: the SDK's console frontend target is `macutil` with output
  # name `mac`, so building everything is the portable option.
  cmake --build "$work/build" -j "$(nproc)" >>"$work/cmake.log" 2>&1 \
    || die "build failed (log: $work/cmake.log)"
  [[ -x "$work/build/mac" ]] || die "build produced no mac binary"

  local banner
  banner=$("$work/build/mac" 2>&1 | head -1 || true)
  grep -q "Monkey's Audio" <<<"$banner" || die "built binary failed sanity run"
  grep -qF "(v $disp)" <<<"$banner" \
    || die "built binary reports wrong version (wanted v $disp, got: $banner)"

  local bin="$PREFIX/bin/mac"
  install -D -m 0755 "$work/build/mac" "$bin"

  install -d -m 0755 "$DATA_DIR"
  {
    printf 'version\t%s\n' "$ver"
    printf 'zip_sha256\t%s\n' "$actual"
    printf 'installed_at\t%s\n' "$(date -Is)"
    printf 'file\t%s\t%s\n' "$bin" "$(sha256_of "$bin")"
  } >"$MANIFEST"
  chmod 0644 "$MANIFEST"

  # Post-install permission verification.
  local mode owner
  mode=$(stat -c '%a' "$bin")
  owner=$(stat -c '%u' "$bin")
  [[ "$mode" == 755 ]] || die "unexpected mode on $bin: $mode (wanted 755)"
  [[ "$owner" == "$(id -u)" ]] || die "unexpected owner on $bin: uid $owner"
  local bindir_mode
  bindir_mode=$(stat -c '%a' "$PREFIX/bin")
  [[ "$bindir_mode" =~ ^[0-7]?[0-7][0-7][0145]$ ]] \
    || warn "$PREFIX/bin is group/world-writable (mode $bindir_mode)"

  info "installed Monkey's Audio $disp -> $bin"
  case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) warn "$PREFIX/bin is not in PATH" ;;
  esac
}

cmd_uninstall() {
  [[ -f "$MANIFEST" ]] || { info "not installed (no manifest at $MANIFEST)"; return 0; }
  local type path hash removed=0
  while IFS=$'\t' read -r type path hash || [[ -n "${type:-}" ]]; do
    [[ "$type" == file ]] || continue
    if [[ ! -f "$path" ]]; then
      warn "already gone: $path"
      continue
    fi
    if [[ "$(sha256_of "$path")" != "$hash" && "$FORCE" -eq 0 ]]; then
      die "$path was modified since install; re-run with --force to remove anyway"
    fi
    rm -f -- "$path"
    info "removed $path"
    removed=$((removed + 1))
  done <"$MANIFEST"
  rm -f -- "$MANIFEST"
  rmdir -- "$DATA_DIR" 2>/dev/null || true
  if [[ "$PURGE" -eq 1 ]]; then
    rm -rf -- "$CACHE_DIR"
    info "purged download cache"
  fi
  info "uninstalled ($removed file(s) removed)"
}

cmd_update() {
  local latest installed disp
  latest=$(latest_version) || die "cannot reach releases page: $RELEASES_URL"
  [[ -n "$latest" ]] || die "no SDK version found at $RELEASES_URL"
  installed=$(manifest_get version || true)

  if [[ -z "$installed" ]]; then
    info "not installed; installing latest"
  elif ((latest <= installed)); then
    info "up to date (installed $(ver_display "$installed"), latest $(ver_display "$latest"))"
    return 0
  else
    info "updating $(ver_display "$installed") -> $(ver_display "$latest")"
  fi
  disp=$(ver_display "$latest")
  VERSION=$latest
  FORCE=1
  cmd_install
  : "$disp"
}

cmd_status() {
  local rc=0
  if [[ ! -f "$MANIFEST" ]]; then
    echo "installed: no"
  else
    echo "installed: yes"
    echo "version:   $(ver_display "$(manifest_get version)")"
    echo "zip sha256: $(manifest_get zip_sha256)"
    echo "installed at: $(manifest_get installed_at)"
    local type path hash
    while IFS=$'\t' read -r type path hash || [[ -n "${type:-}" ]]; do
      [[ "$type" == file ]] || continue
      if [[ ! -f "$path" ]]; then
        echo "file:      $path (MISSING)"
        rc=1
      elif [[ "$(sha256_of "$path")" != "$hash" ]]; then
        echo "file:      $path (MODIFIED - hash mismatch)"
        rc=1
      else
        echo "file:      $path (ok, $(stat -c '%a' "$path"))"
      fi
    done <"$MANIFEST"
  fi
  local latest
  if latest=$(latest_version) && [[ -n "$latest" ]]; then
    echo "latest:    $(ver_display "$latest")"
  else
    echo "latest:    unknown (releases page unreachable)"
  fi
  return "$rc"
}

# --- argument parsing ------------------------------------------------------------

(($# >= 1)) || usage
CMD=$1
shift

while (($# > 0)); do
  case "$1" in
    --version)
      [[ -n "${2:-}" ]] || usage
      VERSION=$(ver_norm "$2"); shift 2 ;;
    --version=*) VERSION=$(ver_norm "${1#--version=}"); shift ;;
    --sha256)
      [[ -n "${2:-}" ]] || usage
      SHA256=$2; shift 2 ;;
    --sha256=*) SHA256=${1#--sha256=}; shift ;;
    --prefix)
      [[ -n "${2:-}" ]] || usage
      PREFIX=$2; shift 2 ;;
    --prefix=*) PREFIX=${1#--prefix=}; shift ;;
    --force) FORCE=1; shift ;;
    --purge) PURGE=1; shift ;;
    -h | --help) usage 0 ;;
    *) echo "ape-codec: unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$SHA256" || "$SHA256" =~ ^[0-9a-f]{64}$ ]] \
  || die "--sha256 must be 64 hex chars"

case "$CMD" in
  install) cmd_install ;;
  uninstall) cmd_uninstall ;;
  update) cmd_update ;;
  status) cmd_status ;;
  -h | --help) usage 0 ;;
  *) echo "ape-codec: unknown command: $CMD" >&2; usage ;;
esac
