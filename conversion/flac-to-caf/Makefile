# flac-to-caf
TOOL = flac-to-caf
SCRIPTS = flac-to-caf.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flac2caf.*
DELETE_TARGET = delete-sources
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Extra: convert-verbose
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
