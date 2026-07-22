TOOL = flac-replaygain
SCRIPTS = flac-replaygain.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flacrg.*
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Track-only: make convert ARGS='-T' | Force: ARGS='-y'
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
