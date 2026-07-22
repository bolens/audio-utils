#!/usr/bin/env bash
# Run the test suite inside a CI-equivalent container.
#
# GitHub's runners use Ubuntu LTS, whose ffmpeg (6.1) is far older than most
# dev machines'. Bugs that only one end of that range can catch (e.g. the
# fd-0 console-handler decode truncation) are invisible locally without this.
#
# Usage:
#   scripts/test-ci.sh [--ffmpeg apt|latest] [tests/run.sh args...]
#
#   --ffmpeg apt      distro ffmpeg, as on the CI runners (default)
#   --ffmpeg latest   BtbN static build of upstream master, as CI's
#                     "ffmpeg latest" matrix leg
#   remaining args    passed to tests/run.sh (tiers, -k FILTER, -j N ...)
#
# Requires docker or podman. The package layer is baked into a locally
# tagged image and reused, so only the first run pays for apt.
set -euo pipefail

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit "${1:-0}"
}

FFMPEG=apt
declare -a RUN_ARGS=()
while (($# > 0)); do
  case "$1" in
    --ffmpeg)
      [[ "${2:-}" == apt || "${2:-}" == latest ]] || {
        echo "--ffmpeg takes 'apt' or 'latest'" >&2
        exit 2
      }
      FFMPEG=$2
      shift 2
      ;;
    -h | --help) usage 0 ;;
    *)
      RUN_ARGS+=("$1")
      shift
      ;;
  esac
done

if command -v docker >/dev/null 2>&1; then
  ENGINE=docker
elif command -v podman >/dev/null 2>&1; then
  ENGINE=podman
else
  echo "Error: need docker or podman" >&2
  exit 2
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Mirrors the CI functional job's dependency list (.github/workflows/ci.yml).
PKGS="ffmpeg flac bpm-tools musepack-tools libchromaprint-tools
  cmake g++ unzip zip rsgain pkg-config git sox libsox-fmt-all
  libfftw3-dev libavcodec-dev libavformat-dev libavutil-dev libswresample-dev
  util-linux python3 curl ca-certificates xz-utils"
# shellcheck disable=SC2086  # PKGS is a fixed word list
IMAGE="audio-utils-test-ci:$(printf '%s %s' "$PKGS" "$FFMPEG" | sha256sum | cut -c1-12)"

if ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "test-ci: building $IMAGE (one-time)" >&2
  ffmpeg_layer=""
  if [[ "$FFMPEG" == latest ]]; then
    ffmpeg_layer='RUN curl -fsSL --retry 3 -o /tmp/ffmpeg.tar.xz \
      https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz \
      && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp \
      && install -m 0755 /tmp/ffmpeg-master-latest-linux64-gpl/bin/ffmpeg \
        /tmp/ffmpeg-master-latest-linux64-gpl/bin/ffprobe /usr/local/bin/ \
      && rm -rf /tmp/ffmpeg*'
  fi
  "$ENGINE" build -t "$IMAGE" -f - "$REPO_ROOT" <<EOF
FROM ubuntu:24.04
RUN apt-get update \\
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \\
    ${PKGS//$'\n'/ } \\
  && rm -rf /var/lib/apt/lists/*
${ffmpeg_layer}
# Non-root: the suite legitimately fails as root (chmod cannot revoke
# root's access, breaking unwritable-dir tests) and CI runners are non-root.
RUN useradd -m ci
USER ci
WORKDIR /home/ci
EOF
fi

# Copy the repo out of the read-only mount so tools can write state/scratch;
# drop any host fixture cache (built by a different ffmpeg).
# shellcheck disable=SC2016  # single quotes intended: expands in-container
exec "$ENGINE" run --rm -v "$REPO_ROOT":/repo:ro "$IMAGE" bash -c '
  set -euo pipefail
  cp -r /repo "$HOME/work"
  cd "$HOME/work"
  rm -rf tests/.cache
  ffmpeg -version | head -1
  # Best-effort optional tools (same spirit as CI continue-on-error).
  bash scripts/ape-codec.sh install --prefix "$HOME/.local" || true
  bash scripts/keyfinder-cli.sh install --prefix "$HOME/.local" || true
  export PATH="$HOME/.local/bin:$PATH"
  export LD_LIBRARY_PATH="$HOME/.local/lib:$HOME/.local/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
  exec bash tests/run.sh "$@"
' _ "${RUN_ARGS[@]}"
