# audio-utils — top-level helpers
#
# Tools live under conversion/ and util/. Shared library: lib/

SHELLCHECK = shellcheck -x -a
JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

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
	util/audio-replaygain util/audio-tags util/audio-bpm util/audio-key \
	util/audio-dupes util/audio-artwork \
	util/library-sync util/tree-diff util/hash-verify util/pcm-cleanup \
  util/cue-audit util/silence-detect util/disc-inventory util/lossy-audit \
	util/playlist-audit util/playlist-normalize util/playlist-generate \
	util/playlist-dedupe \
	util/path-audit util/junk-cleanup util/perms-normalize util/album-audit \
	util/dynamics-report util/spectrogram-export util/gapless-audit \
	util/tags-lookup util/audio-lyrics util/playlist-export util/library-prune

TOOLS = $(CONVERSION) $(UTIL)

LIB_SCRIPTS = \
	lib/load.sh lib/log.sh lib/compat.sh lib/xdg.sh lib/config.sh lib/version.sh \
	lib/progress.sh lib/tmpdir.sh lib/probe.sh lib/disk.sh lib/util.sh \
	lib/success_log.sh lib/delete.sh lib/convert_all.sh lib/pcm_remux.sh \
	lib/pcm_to_flac.sh lib/lossless.sh lib/plugin_init.sh lib/cli.sh \
	lib/find-audio-dirs.sh lib/driver.sh lib/worker.sh lib/pcm_flac.sh \
	lib/cue.sh lib/playlist.sh lib/tags.sh lib/audio_meta.sh lib/lossy.sh lib/tak.sh lib/dvd.sh lib/cdda.sh \
	lib/bluray.sh lib/run_parallel.sh

RUN_PARALLEL = $(CURDIR)/lib/run_parallel.sh

.PHONY: help check check-lib check-conversion check-util check-tools $(addsuffix -%,$(TOOLS))

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check                 shellcheck shared lib + all tools (parallel)"
	@echo "  make check-lib             shellcheck shared lib only"
	@echo "  make check-tools           shellcheck all tools (bash job pool)"
	@echo "  make check-conversion      shellcheck conversion/ tools (parallel)"
	@echo "  make check-util            shellcheck util/ tools (parallel)"
	@echo "  make -C conversion/TOOL help"
	@echo "  make -C util/TOOL help"
	@echo "  make TOOL-check            short alias (e.g. wav-to-flac-check)"
	@echo "  JOBS=N                     concurrency for parallel checks (default: nproc)"
	@echo ""
	@echo "Conversion: $(notdir $(CONVERSION))"
	@echo "Util:       $(notdir $(UTIL))"
	@echo ""
	@echo "Docs:  docs/  (requirements, formats, cue, discs, streaming, tak, lossy, playlists, utils)"
	@echo "Set library roots:"
	@echo "  export AUDIO_UTILS_ROOTS=\"\$$HOME/Music \$$HOME/Downloads\""
	@echo ""
	@echo "Logs:   \$${XDG_STATE_HOME:-\$$HOME/.local/state}/audio-utils/"
	@echo "Config: \$${XDG_CONFIG_HOME:-\$$HOME/.config}/audio-utils/config"

check-lib:
	$(SHELLCHECK) $(LIB_SCRIPTS)

# Single job pool over all tools (avoids oversubscribe from nested -j pools).
check-tools:
	@JOBS=$(JOBS) $(RUN_PARALLEL) -j $(JOBS) $(TOOLS)

check-conversion:
	@JOBS=$(JOBS) $(RUN_PARALLEL) -j $(JOBS) $(CONVERSION)

check-util:
	@JOBS=$(JOBS) $(RUN_PARALLEL) -j $(JOBS) $(UTIL)

# Lib first (fast), then one parallel pool across every tool.
check: check-lib check-tools

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
