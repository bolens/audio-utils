# audio-utils — top-level helpers
#
# Tools live in subdirectories (e.g. wav-to-flac/).
# Shared library: lib/

SHELLCHECK = shellcheck -x -a

.PHONY: help check test wav-to-flac-%

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check              shellcheck shared lib + all tools"
	@echo "  make -C wav-to-flac help"
	@echo "  make wav-to-flac-convert   # delegates: make -C wav-to-flac convert"
	@echo ""
	@echo "Set library roots for discover/clean:"
	@echo "  export AUDIO_UTILS_ROOTS=\"\$$HOME/Music \$$HOME/Downloads\""
	@echo ""
	@echo "Logs (XDG): \$${XDG_STATE_HOME:-\$$HOME/.local/state}/audio-utils/"
	@echo "Config:     \$${XDG_CONFIG_HOME:-\$$HOME/.config}/audio-utils/config"
	@echo "Runtime:    \$$XDG_RUNTIME_DIR/audio-utils/ (else cache)"

check:
	$(SHELLCHECK) lib/load.sh lib/log.sh lib/xdg.sh lib/config.sh lib/version.sh \
		lib/progress.sh lib/tmpdir.sh lib/probe.sh lib/disk.sh lib/util.sh \
		lib/find-audio-dirs.sh
	$(MAKE) -C wav-to-flac check

# Delegate: make wav-to-flac-convert → make -C wav-to-flac convert
wav-to-flac-%:
	$(MAKE) -C wav-to-flac $*
