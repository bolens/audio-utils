# wv-to-flac
TOOL = wv-to-flac
SCRIPTS = wv-to-flac.sh find-wv-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-wv-dirs.sh
WORKDIR_GLOB = .wv2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
