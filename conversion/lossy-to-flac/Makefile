# lossy-to-flac
TOOL = lossy-to-flac
SCRIPTS = lossy-to-flac.sh find-lossy-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-lossy-dirs.sh
WORKDIR_GLOB = .lossy2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
