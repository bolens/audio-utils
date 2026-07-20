# audio-utils — top-level helpers
#
# Tools live in subdirectories (wav-to-flac/, flac-to-wav/, flac-to-mp3/).
# Shared library: lib/

SHELLCHECK = shellcheck -x -a

.PHONY: help check test wav-to-flac-% flac-to-wav-% flac-to-mp3-%

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check                 shellcheck shared lib + all tools"
	@echo "  make -C wav-to-flac help"
	@echo "  make -C flac-to-wav help"
	@echo "  make -C flac-to-mp3 help"
	@echo "  make wav-to-flac-convert   # delegates"
	@echo "  make flac-to-wav-convert"
	@echo "  make flac-to-mp3-convert"
	@echo ""
	@echo "Set library roots:"
	@echo "  export AUDIO_UTILS_ROOTS=\"\$$HOME/Music \$$HOME/Downloads\""
	@echo ""
	@echo "Logs:   \$${XDG_STATE_HOME:-\$$HOME/.local/state}/audio-utils/"
	@echo "Config: \$${XDG_CONFIG_HOME:-\$$HOME/.config}/audio-utils/config"

check:
	$(SHELLCHECK) lib/load.sh lib/log.sh lib/xdg.sh lib/config.sh lib/version.sh \
		lib/progress.sh lib/tmpdir.sh lib/probe.sh lib/disk.sh lib/util.sh \
		lib/find-audio-dirs.sh lib/driver.sh lib/worker.sh
	$(MAKE) -C wav-to-flac check
	$(MAKE) -C flac-to-wav check
	$(MAKE) -C flac-to-mp3 check

wav-to-flac-%:
	$(MAKE) -C wav-to-flac $*

flac-to-wav-%:
	$(MAKE) -C flac-to-wav $*

flac-to-mp3-%:
	$(MAKE) -C flac-to-mp3 $*
