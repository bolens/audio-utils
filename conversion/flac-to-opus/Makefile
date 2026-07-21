# flac-to-opus
TOOL = flac-to-opus
SCRIPTS = flac-to-opus.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flac2opus.*
DELETE_TARGET = delete-sources
HELP_EXTRA =   Quality: make convert ARGS='-Q 128'
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
