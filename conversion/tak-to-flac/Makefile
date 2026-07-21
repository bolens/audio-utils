# tak-to-flac
TOOL = tak-to-flac
SCRIPTS = tak-to-flac.sh find-tak-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-tak-dirs.sh
WORKDIR_GLOB = .tak2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
