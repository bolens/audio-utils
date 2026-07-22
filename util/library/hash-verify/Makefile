TOOL = hash-verify
SCRIPTS = hash-verify.sh find-audio-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-audio-dirs.sh
WORKDIR_GLOB = .hashverify.*
HAS_CONVERT_VERBOSE = 1
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
