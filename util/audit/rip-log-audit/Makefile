TOOL = rip-log-audit
SCRIPTS = rip-log-audit.sh find-log-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-log-dirs.sh
WORKDIR_GLOB = .riplogaudit.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
