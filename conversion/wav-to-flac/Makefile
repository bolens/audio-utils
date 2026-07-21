# wav-to-flac
TOOL = wav-to-flac
SCRIPTS = wav-to-flac.sh find-wav-dirs.sh convert-all.sh lib/*.sh
FIND_SCRIPT = find-wav-dirs.sh
WORKDIR_GLOB = .wav2flac.*
DELETE_TARGET = delete-wavs
HAS_CONVERT_VERBOSE = 1
HAS_CONVERT_CLEAN = 1
HAS_RETAG = 1
HELP_EXTRA =   Extra: convert-verbose / convert-clean / retag
CLEAN_EXTRA = rm -f wav-to-flac-failures.log wav-to-flac-success.csv wav-to-flac-success.jsonl;
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
