TOOL = playlist-export
SCRIPTS = playlist-export.sh find-playlist-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-playlist-dirs.sh
WORKDIR_GLOB = .plexp.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
