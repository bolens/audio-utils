TOOL = flac-dupes
SCRIPTS = flac-dupes.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flacdupes.*
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Fingerprint: make convert ARGS='--fingerprint'
HAS_DELETE = 0
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
