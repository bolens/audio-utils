# audio-utils — top-level helpers
#
# Tools live under conversion/ and util/. Shared library: lib/

SHELLCHECK = shellcheck -x -a

CONVERSION = \
	conversion/wav-to-flac conversion/flac-to-wav conversion/flac-to-mp3 \
	conversion/aiff-to-flac conversion/flac-to-aiff \
	conversion/flac-to-alac conversion/alac-to-flac \
	conversion/flac-to-wv conversion/wv-to-flac \
	conversion/cue-to-flac \
	conversion/ape-to-flac conversion/flac-to-ape \
	conversion/tak-to-flac conversion/flac-to-tak \
	conversion/tta-to-flac conversion/flac-to-tta conversion/shn-to-flac \
	conversion/wav-to-aiff conversion/aiff-to-wav \
	conversion/caf-to-flac conversion/flac-to-caf \
	conversion/flac-to-opus conversion/flac-to-aac conversion/flac-to-vorbis \
	conversion/flac-to-wma conversion/flac-to-speex conversion/flac-to-mpc \
	conversion/lossy-to-flac conversion/dsf-to-flac \
	conversion/streams-to-flac conversion/dvd-to-flac conversion/cdda-to-flac \
	conversion/bluray-to-flac

UTIL = \
	util/flac-verify util/flac-replaygain util/flac-artwork util/flac-audit \
	util/flac-authenticity util/flac-tags util/flac-dupes util/flac-optimize \
	util/flac-rename util/flac-cue-export util/flac-strip util/flac-inventory \
	util/audio-replaygain util/audio-tags util/audio-dupes util/audio-artwork \
	util/library-sync util/tree-diff util/hash-verify util/pcm-cleanup \
	util/cue-audit util/silence-detect util/disc-inventory util/lossy-audit

TOOLS = $(CONVERSION) $(UTIL)

.PHONY: help check test $(addsuffix -%,$(TOOLS))

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check                 shellcheck shared lib + all tools"
	@echo "  make -C conversion/TOOL help"
	@echo "  make -C util/TOOL help"
	@echo "  make TOOL-check            short alias (e.g. wav-to-flac-check)"
	@echo ""
	@echo "Conversion: $(notdir $(CONVERSION))"
	@echo "Util:       $(notdir $(UTIL))"
	@echo ""
	@echo "Docs:  docs/  (requirements, formats, cue, discs, streaming, tak, lossy, utils)"
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
		lib/cue.sh lib/tags.sh lib/audio_meta.sh lib/lossy.sh lib/tak.sh lib/dvd.sh lib/cdda.sh \
		lib/bluray.sh
	@for t in $(TOOLS); do $(MAKE) -C $$t check || exit 1; done

# Forward make -C PATH TARGET via e.g. `make conversion/cue-to-flac-check`
define TOOL_FORWARD
$(1)-%:
	$$(MAKE) -C $(1) $$*
endef
$(foreach t,$(TOOLS),$(eval $(call TOOL_FORWARD,$(t))))

# Short aliases: make wav-to-flac-check → make -C conversion/wav-to-flac check
define TOOL_ALIAS
$(notdir $(1))-%:
	$$(MAKE) -C $(1) $$*
endef
$(foreach t,$(TOOLS),$(eval $(call TOOL_ALIAS,$(t))))
