TOOL = library-prune
SCRIPTS = library-prune.sh find-portable-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-portable-dirs.sh
WORKDIR_GLOB = .libprune.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 1
HAS_DELETE_EXISTING = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
