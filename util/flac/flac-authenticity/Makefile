TOOL = flac-authenticity
SCRIPTS = flac-authenticity.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flacauth.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
