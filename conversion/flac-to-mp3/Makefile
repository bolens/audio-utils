# flac-to-mp3
TOOL = flac-to-mp3
SCRIPTS = flac-to-mp3.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flac2mp3.*
DELETE_TARGET = delete-flacs
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Quality: make convert ARGS='-Q v0'
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
