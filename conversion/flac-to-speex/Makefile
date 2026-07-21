# flac-to-speex
TOOL = flac-to-speex
SCRIPTS = flac-to-speex.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flac2speex.*
DELETE_TARGET = delete-sources
HELP_EXTRA =   Quality: make convert ARGS='-Q q6'
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
