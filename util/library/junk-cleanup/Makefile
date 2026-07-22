TOOL = junk-cleanup
SCRIPTS = junk-cleanup.sh find-junk-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-junk-dirs.sh
WORKDIR_GLOB = .junkclean.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 1
HAS_DELETE_EXISTING = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
