# aiff-to-wav
TOOL = aiff-to-wav
SCRIPTS = aiff-to-wav.sh find-aiff-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-aiff-dirs.sh
WORKDIR_GLOB = .aiff2wav.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
