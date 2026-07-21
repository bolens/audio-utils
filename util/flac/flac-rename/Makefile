TOOL = flac-rename
SCRIPTS = flac-rename.sh find-flac-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-flac-dirs.sh
WORKDIR_GLOB = .flacrename.*
HAS_CONVERT_VERBOSE = 1
HELP_EXTRA =   Layout: make convert ARGS='--layout=artist-album'
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
