# caf-to-flac
TOOL = caf-to-flac
SCRIPTS = caf-to-flac.sh find-caf-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-caf-dirs.sh
WORKDIR_GLOB = .caf2flac.*
DELETE_TARGET = delete-sources
HAS_CONVERT_VERBOSE = 1
HAS_CONVERT_CLEAN = 1
HAS_RETAG = 1
HELP_EXTRA =   Extra: convert-verbose / convert-clean / retag
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
