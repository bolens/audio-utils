# audio-utils — top-level helpers
#
# Tools live in subdirectories. Shared library: lib/

SHELLCHECK = shellcheck -x -a

TOOLS = wav-to-flac flac-to-wav flac-to-mp3 \
	aiff-to-flac flac-to-aiff \
	flac-to-alac alac-to-flac \
	flac-to-wv wv-to-flac \
	cue-to-flac \
	ape-to-flac flac-to-ape \
	tak-to-flac flac-to-tak \
	wav-to-aiff aiff-to-wav \
	flac-to-opus flac-to-aac flac-to-vorbis \
	streams-to-flac dvd-to-flac cdda-to-flac bluray-to-flac

.PHONY: help check test $(addsuffix -%,$(TOOLS))

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check                 shellcheck shared lib + all tools"
	@echo "  make -C TOOL help          per-tool targets"
	@echo ""
	@echo "Tools: $(TOOLS)"
	@echo ""
	@echo "Docs:  docs/  (requirements, formats, cue, discs, streaming, tak, lossy)"
	@echo "Set library roots:"
	@echo "  export AUDIO_UTILS_ROOTS=\"\$$HOME/Music \$$HOME/Downloads\""
	@echo ""
	@echo "Logs:   \$${XDG_STATE_HOME:-\$$HOME/.local/state}/audio-utils/"
	@echo "Config: \$${XDG_CONFIG_HOME:-\$$HOME/.config}/audio-utils/config"

check:
	$(SHELLCHECK) lib/load.sh lib/log.sh lib/xdg.sh lib/config.sh lib/version.sh \
		lib/progress.sh lib/tmpdir.sh lib/probe.sh lib/disk.sh lib/util.sh \
		lib/success_log.sh lib/delete.sh lib/convert_all.sh lib/pcm_remux.sh \
		lib/pcm_to_flac.sh lib/lossless.sh lib/plugin_init.sh lib/cli.sh \
		lib/find-audio-dirs.sh lib/driver.sh lib/worker.sh lib/pcm_flac.sh \
		lib/cue.sh lib/lossy.sh lib/tak.sh lib/dvd.sh lib/cdda.sh lib/bluray.sh
	@for t in $(TOOLS); do $(MAKE) -C $$t check || exit 1; done

# Forward make -C TOOL TARGET via e.g. `make cue-to-flac-check`
define TOOL_FORWARD
$(1)-%:
	$$(MAKE) -C $(1) $$*
endef
$(foreach t,$(TOOLS),$(eval $(call TOOL_FORWARD,$(t))))
