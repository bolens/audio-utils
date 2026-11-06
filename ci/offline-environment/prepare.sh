#!/usr/bin/env bash
# Offline pinned CLI-root materialization and metadata; no dependency build/evaluation.
set -euo pipefail
[[ $# == 0 && -f source-identity.json ]]
# shellcheck source=ci/offline-environment/bootstrap.sh
source ci/offline-environment/bootstrap.sh manifest
export PATH="$PWD/.devenv/profile/bin:$PATH"
cli_source=$(/opt/audio-ci/python -c 'import json,os;d=json.load(open("/tmp/audio-ci-cli-source.json"));assert d["locked"]["rev"]==os.environ["AUDIO_CI_DEVENV_REV"];print(d["path"])')
/opt/audio-ci/python scripts/ci/offline_environment.py prepare --root /opt/audio-ci-input --output /opt/audio-ci/environment.json --cli /opt/audio-ci/devenv/bin/devenv --cli-source "$cli_source"
cp -- scripts/ci/offline_environment.py /opt/audio-ci/offline_environment.py
chmod 0755 /opt/audio-ci/offline_environment.py
rm -rf -- /opt/audio-ci/npm-cache/_logs
