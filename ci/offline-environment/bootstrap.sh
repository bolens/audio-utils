#!/usr/bin/env bash
# Stable preparation policy shared by both cacheable Docker RUNs.
set -euo pipefail
[[ $EUID == 0 && ${AUDIO_CI_ENV_PREPARE:-} == 1 && ${NIX_REMOTE:-} == local ]]
[[ $PWD == /opt/audio-ci-input ]]
[[ ${AUDIO_CI_DEVENV_REV:-} =~ ^[0-9a-f]{40}$ ]]
[[ ${AUDIO_CI_NIX_BASE:-} == *@sha256:* ]]
audio_ci_phase=${1:-}
[[ $audio_ci_phase == realize || $audio_ci_phase == manifest ]]
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
printf 'offline-environment-build-limits phase=%s cpu=%s/%s memory=%s swap=%s\n' "$audio_ci_phase" "$cpu_quota" "$cpu_period" "$memory_max" "$swap_max"
# Literal newlines are required: Dockerfile ENV quoted \n is not a newline.
export NIX_CONFIG='experimental-features = nix-command flakes
sandbox = false
build-users-group =
max-jobs = 1
cores = 2
extra-substituters = https://devenv.cachix.org
extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw='
