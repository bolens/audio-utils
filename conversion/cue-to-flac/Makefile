# cue-to-flac
TOOL = cue-to-flac
SCRIPTS = cue-to-flac.sh find-cue-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-cue-dirs.sh
WORKDIR_GLOB = .cue2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
