#!/usr/bin/env bash
# Only the explicit isolated Dockerfile preparation stage executes this script.
set -euo pipefail
[[ $EUID == 0 && ${AUDIO_CI_ENV_PREPARE:-} == 1 && ${NIX_REMOTE:-} == local ]]
[[ $PWD == /opt/audio-ci-input && -f source-identity.json ]]
[[ ${AUDIO_CI_DEVENV_REV:-} =~ ^[0-9a-f]{40}$ ]]
[[ ${AUDIO_CI_NIX_BASE:-} == *@sha256:* ]]
for name in GH_TOKEN GITHUB_TOKEN GITHUB_PUBLISH_LEASE PUBLISHER_LEASE NPM_TOKEN NIX_USER_CONF_FILES; do
  [[ -z ${!name-} ]]
done
# Refuse unsupported BuildKit resource enforcement before any Nix/network work.
read -r cpu_quota cpu_period < /sys/fs/cgroup/cpu.max
read -r memory_max < /sys/fs/cgroup/memory.max
read -r swap_max < /sys/fs/cgroup/memory.swap.max
[[ $cpu_quota =~ ^[0-9]+$ && $cpu_period =~ ^[1-9][0-9]*$ ]]
(( cpu_quota == 2 * cpu_period ))
[[ $memory_max == 4294967296 && $swap_max == 0 ]]
printf 'offline-environment-build-limits cpu=%s/%s memory=%s swap=%s\n' "$cpu_quota" "$cpu_period" "$memory_max" "$swap_max"
# Literal newlines are required: Dockerfile ENV quoted \n is not a newline.
export NIX_CONFIG='experimental-features = nix-command flakes
sandbox = false
build-users-group =
max-jobs = 1
cores = 2
extra-substituters = https://devenv.cachix.org
extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw='
if [[ ${1:-} == --inside-shell ]]; then
  npm ci --prefix mcp/npm --ignore-scripts --no-audit --no-fund --cache /opt/audio-ci/npm-cache
  npm cache verify --cache /opt/audio-ci/npm-cache
  cli_source=$(python3 -c 'import json,os;d=json.load(open("/tmp/audio-ci-cli-source.json"));assert d["locked"]["rev"]==os.environ["AUDIO_CI_DEVENV_REV"];print(d["path"])')
  python3 scripts/ci/offline_environment.py prepare --root /opt/audio-ci-input --output /opt/audio-ci/environment.json --cli /opt/audio-ci/devenv/bin/devenv --cli-source "$cli_source"
  ln -s "$(command -v python3)" /opt/audio-ci/python
  exit 0
fi
[[ $# == 0 ]]
mkdir -p /opt/audio-ci/npm-cache
nix --version > /tmp/audio-ci-base-nix-version
reference="github:cachix/devenv/$AUDIO_CI_DEVENV_REV"
nix build --accept-flake-config --out-link /opt/audio-ci/devenv "$reference"
nix flake metadata --json "$reference" > /tmp/audio-ci-cli-source.json
/opt/audio-ci/devenv/bin/devenv --max-jobs 1 --cores 2 build shell test
# Realize shell/test outputs and public npm content. Do not execute product tests
# here: warmup is not offline readiness or current-source proof.
/opt/audio-ci/devenv/bin/devenv --max-jobs 1 --cores 2 shell -- bash ci/offline-environment/prepare.sh --inside-shell
cp -- scripts/ci/offline_environment.py /opt/audio-ci/offline_environment.py
chmod 0755 /opt/audio-ci/offline_environment.py
rm -rf -- /opt/audio-ci/npm-cache/_logs
