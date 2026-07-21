TOOL = flac-tags
SCRIPTS = flac-tags.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flactags.*
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Fill albumartist: make convert ARGS='-A'
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
