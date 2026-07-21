# ape-to-flac
TOOL = ape-to-flac
SCRIPTS = ape-to-flac.sh find-ape-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-ape-dirs.sh
WORKDIR_GLOB = .ape2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
