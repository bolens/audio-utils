# caf-to-flac
TOOL = caf-to-flac
SCRIPTS = caf-to-flac.sh find-caf-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-caf-dirs.sh
WORKDIR_GLOB = .caf2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
