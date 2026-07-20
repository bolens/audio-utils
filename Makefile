# audio-utils — top-level helpers
#
# Tools live in subdirectories. Shared library: lib/

SHELLCHECK = shellcheck -x -a

TOOLS = wav-to-flac flac-to-wav flac-to-mp3 \
	aiff-to-flac flac-to-aiff \
	flac-to-alac alac-to-flac \
	flac-to-wv wv-to-flac

.PHONY: help check test $(addsuffix -%,$(TOOLS))

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check                 shellcheck shared lib + all tools"
	@echo "  make -C TOOL help          per-tool targets"
	@echo ""
	@echo "Tools: $(TOOLS)"
	@echo ""
	@echo "Set library roots:"
	@echo "  export AUDIO_UTILS_ROOTS=\"\$$HOME/Music \$$HOME/Downloads\""
	@echo ""
	@echo "Logs:   \$${XDG_STATE_HOME:-\$$HOME/.local/state}/audio-utils/"
	@echo "Config: \$${XDG_CONFIG_HOME:-\$$HOME/.config}/audio-utils/config"

check:
	$(SHELLCHECK) lib/load.sh lib/log.sh lib/xdg.sh lib/config.sh lib/version.sh \
		lib/progress.sh lib/tmpdir.sh lib/probe.sh lib/disk.sh lib/util.sh \
		lib/find-audio-dirs.sh lib/driver.sh lib/worker.sh lib/pcm_flac.sh
	@for t in $(TOOLS); do $(MAKE) -C $$t check || exit 1; done

wav-to-flac-%:
	$(MAKE) -C wav-to-flac $*

flac-to-wav-%:
	$(MAKE) -C flac-to-wav $*

flac-to-mp3-%:
	$(MAKE) -C flac-to-mp3 $*

aiff-to-flac-%:
	$(MAKE) -C aiff-to-flac $*

flac-to-aiff-%:
	$(MAKE) -C flac-to-aiff $*

flac-to-alac-%:
	$(MAKE) -C flac-to-alac $*

alac-to-flac-%:
	$(MAKE) -C alac-to-flac $*

flac-to-wv-%:
	$(MAKE) -C flac-to-wv $*

wv-to-flac-%:
	$(MAKE) -C wv-to-flac $*
