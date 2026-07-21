TOOL = playlist-audit
SCRIPTS = playlist-audit.sh find-playlist-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-playlist-dirs.sh
WORKDIR_GLOB = .plaudit.*
HAS_CONVERT_VERBOSE = 1
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
