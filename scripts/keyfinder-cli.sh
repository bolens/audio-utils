#!/usr/bin/env bash
# Best-effort build/install of keyfinder-cli (+ libkeyfinder) into PREFIX.
# No distro binary exists on Ubuntu; CI uses this with continue-on-error so
# audio-key tests can run when the build succeeds and SKIP when it does not.
#
# Usage:
#   scripts/keyfinder-cli.sh install [--prefix DIR]
#
# Exit codes: 0 ok, 1 failure, 2 usage
set -euo pipefail

usage() {
  sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

PREFIX=${HOME}/.local
CMD=""
while (($# > 0)); do
  case "$1" in
    install) CMD=install; shift ;;
    --prefix)
      [[ -n "${2:-}" ]] || usage 2
      PREFIX=$2
      shift 2
      ;;
    -h | --help) usage 0 ;;
    *) usage 2 ;;
  esac
done
[[ "$CMD" == install ]] || usage 2

if command -v keyfinder-cli >/dev/null 2>&1; then
  echo "keyfinder-cli: already on PATH ($(command -v keyfinder-cli))"
  exit 0
fi
if [[ -x "${PREFIX}/bin/keyfinder-cli" ]]; then
  echo "keyfinder-cli: already installed at ${PREFIX}/bin/keyfinder-cli"
  exit 0
fi

need=(cmake g++ pkg-config)
for c in "${need[@]}"; do
  command -v "$c" >/dev/null 2>&1 || {
    echo "keyfinder-cli: missing $c" >&2
    exit 1
  }
done

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/keyfinder-build.XXXXXX")
cleanup() { rm -rf -- "$WORKDIR"; }
trap cleanup EXIT

echo "keyfinder-cli: building libkeyfinder → ${PREFIX}"
git clone --depth 1 https://github.com/mixxxdj/libkeyfinder.git \
  "$WORKDIR/libkeyfinder"
cmake -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -S "$WORKDIR/libkeyfinder" -B "$WORKDIR/libkeyfinder/build"
cmake --build "$WORKDIR/libkeyfinder/build" --parallel "$(nproc)"
cmake --install "$WORKDIR/libkeyfinder/build"

echo "keyfinder-cli: building keyfinder-cli → ${PREFIX}"
git clone --depth 1 https://github.com/evanpurkhiser/keyfinder-cli.git \
  "$WORKDIR/keyfinder-cli"
# Prefer PREFIX for pkg-config / rpath lookup of the just-installed lib.
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX" \
  -S "$WORKDIR/keyfinder-cli" -B "$WORKDIR/keyfinder-cli/build"
cmake --build "$WORKDIR/keyfinder-cli/build" --parallel "$(nproc)"
cmake --install "$WORKDIR/keyfinder-cli/build"

[[ -x "${PREFIX}/bin/keyfinder-cli" ]] || {
  echo "keyfinder-cli: install did not produce ${PREFIX}/bin/keyfinder-cli" >&2
  exit 1
}
echo "keyfinder-cli: installed ${PREFIX}/bin/keyfinder-cli"
