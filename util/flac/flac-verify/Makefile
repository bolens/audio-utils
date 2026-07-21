TOOL = flac-verify
SCRIPTS = flac-verify.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flacverify.*
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Deep MD5: make convert ARGS='-M'
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
