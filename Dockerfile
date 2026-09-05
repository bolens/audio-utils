FROM docker.io/library/debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
LABEL org.opencontainers.image.source="https://github.com/bolens/audio-utils"
# Use maintained distribution packages. Refresh the base digest and rebuild for updates.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends bash python3 ffmpeg flac util-linux findutils gawk grep sed \
        bpm-tools musepack-tools libchromaprint-tools rsgain sox libsox-fmt-all \
        mediainfo cdparanoia dvdbackup minisign par2 icu-devtools jq curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 utils \
    && useradd --uid 10001 --gid 10001 --no-log-init --create-home utils
ENV LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    HOME=/tmp \
    XDG_CONFIG_HOME=/tmp/config \
    XDG_CACHE_HOME=/tmp/cache \
    XDG_STATE_HOME=/tmp/state \
    XDG_DATA_HOME=/tmp/data \
    XDG_RUNTIME_DIR=/tmp/runtime
WORKDIR /opt/audio-utils
COPY lib/ ./lib/
COPY conversion/ ./conversion/
COPY util/ ./util/
COPY VERSION LICENSE ./
COPY mcp/*.sh ./mcp/
COPY scripts/docker-entrypoint.sh /usr/local/bin/audio-utils
USER 10001:10001
WORKDIR /data
ENTRYPOINT ["/usr/local/bin/audio-utils"]
CMD ["--help"]
