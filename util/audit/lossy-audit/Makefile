TOOL = lossy-audit
SCRIPTS = lossy-audit.sh find-lossy-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-lossy-dirs.sh
WORKDIR_GLOB = .lossyaudit.*
HAS_CONVERT_VERBOSE = 1
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
