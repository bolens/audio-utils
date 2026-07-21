# streams-to-flac
TOOL = streams-to-flac
SCRIPTS = streams-to-flac.sh find-media-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-media-dirs.sh
WORKDIR_GLOB = .streams2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
