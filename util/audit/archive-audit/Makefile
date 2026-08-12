TOOL = archive-audit
SCRIPTS = archive-audit.sh find-archive-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-archive-dirs.sh
WORKDIR_GLOB = .archiveaudit.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
