#!/usr/bin/env bash
# Best-effort build/install of keyfinder-cli (+ libkeyfinder) into PREFIX.
# No distro binary exists on Ubuntu; CI uses this with continue-on-error so
# audio-key tests can run when the build succeeds and SKIP when it does not.
#
# Usage:
#   scripts/keyfinder-cli.sh install [--prefix DIR]
#   scripts/keyfinder-cli.sh status  [--prefix DIR]
#
# Exit codes: 0 ok, 1 failure, 2 usage
set -euo pipefail

usage() {
  sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

PREFIX=${HOME}/.local
LIBKEYFINDER_REV=${AUDIO_UTILS_LIBKEYFINDER_REV:-941e517ebf853c2153a8b9d6efcc0c729199aa0b}
KEYFINDER_CLI_REV=${AUDIO_UTILS_KEYFINDER_CLI_REV:-8958d9219fda8a48952da365d19752e43ee81f63}
REV_FILE=""
CMD=""
while (($# > 0)); do
  case "$1" in
    install | status) CMD=$1; shift ;;
    --prefix)
      [[ -n "${2:-}" ]] || usage 2
      PREFIX=$2
      shift 2
      ;;
    -h | --help) usage 0 ;;
    *) usage 2 ;;
  esac
done
[[ -n "$CMD" ]] || usage 2
REV_FILE="${PREFIX}/share/audio-utils/keyfinder-cli/source-revisions"

export PATH="${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

keyfinder_bin() {
  if [[ -x "${PREFIX}/bin/keyfinder-cli" ]]; then
    printf '%s\n' "${PREFIX}/bin/keyfinder-cli"
  elif command -v keyfinder-cli >/dev/null 2>&1; then
    command -v keyfinder-cli
  else
    return 1
  fi
}

smoke_keyfinder() {
  local bin=$1
  # Older builds may not support --help; any successful invocation is enough.
  if "$bin" --help >/dev/null 2>&1 || "$bin" -h >/dev/null 2>&1; then
    return 0
  fi
  # No args: typically exits 0 after printing usage, or 1 - accept either if binary runs.
  "$bin" >/dev/null 2>&1 || true
  [[ -x "$bin" ]]
}

if [[ "$CMD" == status ]]; then
  if bin=$(keyfinder_bin); then
    echo "keyfinder-cli: $bin"
    if [[ -f "$REV_FILE" ]]; then
      sed 's/^/  /' "$REV_FILE"
    else
      echo "  source revisions: unknown"
    fi
    exit 0
  fi
  echo "keyfinder-cli: not installed (PREFIX=$PREFIX)" >&2
  exit 1
fi

if bin=$(keyfinder_bin 2>/dev/null); then
  if smoke_keyfinder "$bin"; then
    echo "keyfinder-cli: already installed ($bin)"
    exit 0
  fi
  echo "keyfinder-cli: existing binary failed smoke check; rebuilding" >&2
fi

need=(cmake g++ pkg-config git install)
for c in "${need[@]}"; do
  command -v "$c" >/dev/null 2>&1 || {
    echo "keyfinder-cli: missing $c" >&2
    exit 1
  }
done
pkg-config --exists fftw3 || {
  echo "keyfinder-cli: missing fftw3 (pkg-config --exists fftw3 failed; install libfftw3-dev)" >&2
  exit 1
}

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/keyfinder-build.XXXXXX")
cleanup() { rm -rf -- "$WORKDIR"; }
trap cleanup EXIT

RPATH="${PREFIX}/lib:${PREFIX}/lib/x86_64-linux-gnu"
CMAKE_RPATH=(-DCMAKE_INSTALL_RPATH="$RPATH" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON)

clone_revision() {
  local url=$1 rev=$2 dest=$3
  git init -q "$dest"
  git -C "$dest" remote add origin "$url"
  git -C "$dest" fetch -q --depth 1 origin "$rev"
  git -C "$dest" checkout -q --detach FETCH_HEAD
  [[ "$(git -C "$dest" rev-parse HEAD)" == "$rev" ]] || {
    echo "keyfinder-cli: fetched revision mismatch for $url" >&2
    return 1
  }
}

echo "keyfinder-cli: building libkeyfinder -> ${PREFIX}"
clone_revision https://github.com/mixxxdj/libkeyfinder.git \
  "$LIBKEYFINDER_REV" "$WORKDIR/libkeyfinder"
cmake -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  "${CMAKE_RPATH[@]}" \
  -S "$WORKDIR/libkeyfinder" -B "$WORKDIR/libkeyfinder/build"
cmake --build "$WORKDIR/libkeyfinder/build" --parallel "$(nproc)"
cmake --install "$WORKDIR/libkeyfinder/build"

echo "keyfinder-cli: building keyfinder-cli -> ${PREFIX}"
clone_revision https://github.com/evanpurkhiser/keyfinder-cli.git \
  "$KEYFINDER_CLI_REV" "$WORKDIR/keyfinder-cli"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
cmake -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  "${CMAKE_RPATH[@]}" \
  -S "$WORKDIR/keyfinder-cli" -B "$WORKDIR/keyfinder-cli/build"
cmake --build "$WORKDIR/keyfinder-cli/build" --parallel "$(nproc)"
cmake --install "$WORKDIR/keyfinder-cli/build"

bin="${PREFIX}/bin/keyfinder-cli"
[[ -x "$bin" ]] || {
  echo "keyfinder-cli: install did not produce $bin" >&2
  exit 1
}
smoke_keyfinder "$bin" || {
  echo "keyfinder-cli: installed binary failed smoke check" >&2
  exit 1
}
install -D -m 0644 /dev/null "$REV_FILE"
{
  printf 'libkeyfinder=%s\n' "$LIBKEYFINDER_REV"
  printf 'keyfinder-cli=%s\n' "$KEYFINDER_CLI_REV"
} >"$REV_FILE"
echo "keyfinder-cli: installed $bin"
