# bluray-to-flac
TOOL = bluray-to-flac
SCRIPTS = bluray-to-flac.sh find-bdmv-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-bdmv-dirs.sh
WORKDIR_GLOB = .bluray2flac.*
DELETE_TARGET = delete-sources
HELP_EXTRA =   Note: BDMV / decrypted media only
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
