# wav-to-aiff
TOOL = wav-to-aiff
SCRIPTS = wav-to-aiff.sh find-wav-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-wav-dirs.sh
WORKDIR_GLOB = .wav2aiff.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
