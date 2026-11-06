#!/usr/bin/env bash
# Stable public dependency layer. Never copy or key mutable checker metadata here.
set -euo pipefail
if [[ ${1:-} == --inside-shell ]]; then
  [[ $EUID == 0 && ${AUDIO_CI_ENV_PREPARE:-} == 1 && ${NIX_REMOTE:-} == local ]]
  [[ $PWD == /opt/audio-ci-input ]]
  npm ci --prefix mcp/npm --ignore-scripts --no-audit --no-fund --cache /opt/audio-ci/npm-cache
  npm cache verify --cache /opt/audio-ci/npm-cache
  python_path=$(python3 -c 'import pathlib,sys;print(pathlib.Path(sys.executable).resolve())')
  [[ $python_path == /nix/store/*/bin/python* ]]
  ln -s "$python_path" /opt/audio-ci/python
  exit 0
fi
[[ $# == 0 ]]
# shellcheck source=ci/offline-environment/bootstrap.sh
source ci/offline-environment/bootstrap.sh realize
mkdir -p /opt/audio-ci/npm-cache
nix --version > /tmp/audio-ci-base-nix-version
reference="github:cachix/devenv/$AUDIO_CI_DEVENV_REV"
nix build --accept-flake-config --out-link /opt/audio-ci/devenv "$reference"
nix flake metadata --json "$reference" > /tmp/audio-ci-cli-source.json
/opt/audio-ci/devenv/bin/devenv --max-jobs 1 --cores 2 build shell test
# Realize dependencies, not product tests. Warmup is not offline readiness.
/opt/audio-ci/devenv/bin/devenv --max-jobs 1 --cores 2 shell -- bash ci/offline-environment/realize.sh --inside-shell
