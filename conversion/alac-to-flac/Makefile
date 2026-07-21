# alac-to-flac
TOOL = alac-to-flac
SCRIPTS = alac-to-flac.sh find-m4a-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-m4a-dirs.sh
WORKDIR_GLOB = .alac2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
