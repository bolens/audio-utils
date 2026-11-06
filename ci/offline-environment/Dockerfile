# Preparation may use public upstreams. This file is not selected by live CI.
ARG NIX_BASE=docker.io/nixos/nix:2.35.4@sha256:f159a58f390677f41e8e900a74b6e2f9c7f27b364122ae6acf7a652ce6c551c0
FROM ${NIX_BASE} AS prepare
ARG NIX_BASE
ENV AUDIO_CI_NIX_BASE=${NIX_BASE} \
    AUDIO_CI_DEVENV_REV=42246161fa3bf7cd18f8334d08c73d6aaa8762d3 \
    AUDIO_CI_ENV_PREPARE=1 NIX_REMOTE=local
WORKDIR /opt/audio-ci-input
# Stable, public dependency inputs only. A late checker/key change reuses this
# resource-checked layer without repeating upstream dependency downloads.
COPY devenv.nix devenv.yaml devenv.lock .gitignore /opt/audio-ci-input/
COPY mcp/npm/package.json mcp/npm/package-lock.json /opt/audio-ci-input/mcp/npm/
COPY ci/offline-environment/bootstrap.sh ci/offline-environment/realize.sh /opt/audio-ci-input/ci/offline-environment/
RUN bash ci/offline-environment/realize.sh
# Generated public allowlist; offline CLI-root and closed source-pack preparation.
COPY . /opt/audio-ci-input/
RUN --network=none bash ci/offline-environment/prepare.sh

FROM ${NIX_BASE}
# Fresh private builder store, never a host store. Contents still require the
# external NAR/content + network-none/current-source acceptance before admission.
COPY --from=prepare /nix/store/ /nix/store/
COPY --from=prepare /nix/var/nix/db/ /nix/var/nix/db/
COPY --from=prepare /opt/audio-ci/ /opt/audio-ci/
ENV NIX_REMOTE=local
ENTRYPOINT ["/opt/audio-ci/python", "/opt/audio-ci/offline_environment.py"]
CMD ["--help"]
