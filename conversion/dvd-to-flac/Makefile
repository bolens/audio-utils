# dvd-to-flac
TOOL = dvd-to-flac
SCRIPTS = dvd-to-flac.sh find-video_ts-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-video_ts-dirs.sh
WORKDIR_GLOB = .dvd2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
