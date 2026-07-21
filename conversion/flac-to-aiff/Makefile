# flac-to-aiff
TOOL = flac-to-aiff
SCRIPTS = flac-to-aiff.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flac2aiff.*
DELETE_TARGET = delete-flacs
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Extra: convert-verbose
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
