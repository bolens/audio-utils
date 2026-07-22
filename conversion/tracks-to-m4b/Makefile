# tracks-to-m4b
TOOL = tracks-to-m4b
SCRIPTS = tracks-to-m4b.sh find-audio-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-audio-dirs.sh
WORKDIR_GLOB = .tracks2m4b.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
