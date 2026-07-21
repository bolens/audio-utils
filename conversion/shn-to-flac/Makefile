# shn-to-flac
TOOL = shn-to-flac
SCRIPTS = shn-to-flac.sh find-shn-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-shn-dirs.sh
WORKDIR_GLOB = .shn2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
