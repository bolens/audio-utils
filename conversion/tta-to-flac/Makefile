# tta-to-flac
TOOL = tta-to-flac
SCRIPTS = tta-to-flac.sh find-tta-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-tta-dirs.sh
WORKDIR_GLOB = .tta2flac.*
DELETE_TARGET = delete-sources
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
