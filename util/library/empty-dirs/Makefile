TOOL = empty-dirs
SCRIPTS = empty-dirs.sh find-empty-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-empty-dirs.sh
WORKDIR_GLOB = .emptydirs.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 1
HAS_DELETE_EXISTING = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
