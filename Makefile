# audio-utils — top-level helpers
#
# Tools live under conversion/ and util/<category>/. Shared library: lib/
# Tool dirs are auto-discovered: any directory under conversion/ or util/
# holding a Makefile is a tool, so new tools need no edits here.

SHELLCHECK = shellcheck -x -a
JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

CONVERSION := $(sort $(patsubst %/Makefile,%,$(wildcard conversion/*/Makefile conversion/*/*/Makefile)))
UTIL := $(sort $(patsubst %/Makefile,%,$(wildcard util/*/Makefile util/*/*/Makefile)))
TOOLS = $(CONVERSION) $(UTIL)

LIB_SCRIPTS := $(sort $(wildcard lib/*.sh lib/*/*.sh))

RUN_PARALLEL = $(CURDIR)/lib/cli/run_parallel.sh

TEST_SCRIPTS := tests/run.sh tests/harness.sh tests/fixtures.sh \
	$(sort $(wildcard tests/*/*.test.sh)) \
	$(sort $(wildcard scripts/*.sh))

.PHONY: help check check-lib check-conversion check-util check-tools \
	check-tests test test-functional test-all coverage new-util \
	new-converter $(addsuffix -%,$(TOOLS))

help:
	@echo "audio-utils"
	@echo ""
	@echo "  make check                 shellcheck shared lib + tests + all tools (parallel)"
	@echo "  make check-lib             shellcheck shared lib only"
	@echo "  make check-tools           shellcheck all tools (bash job pool)"
	@echo "  make check-conversion      shellcheck conversion/ tools (parallel)"
	@echo "  make check-util            shellcheck util/ tools (parallel)"
	@echo "  make check-tests           shellcheck the test suite"
	@echo "  make test                  run unit + smoke tests"
	@echo "  make test-functional       run functional tests (needs ffmpeg/flac)"
	@echo "  make test-all              run every test tier"
	@echo "  make coverage              audit test coverage vs the 90% goal"
	@echo "  make -C TOOLDIR test       run smoke + matching tests for one tool"
	@echo "  make new-util CATEGORY=x NAME=y      scaffold util/x/y"
	@echo "  make new-converter NAME=x-to-y       scaffold conversion/x-to-y"
	@echo "  make -C conversion/TOOL help"
	@echo "  make -C util/CATEGORY/TOOL help"
	@echo "  make TOOL-check            short alias (e.g. wav-to-flac-check)"
	@echo "  JOBS=N                     concurrency for parallel checks (default: nproc)"
	@echo ""
	@echo "Conversion: $(notdir $(CONVERSION))"
	@echo "Util:       $(notdir $(UTIL))"
	@echo ""
	@echo "Docs:  docs/  (requirements, formats, cue, discs, streaming, tak, lossy, playlists)"
	@echo "Set library roots:"
	@echo "  export AUDIO_UTILS_ROOTS=\"\$$HOME/Music \$$HOME/Downloads\""
	@echo ""
	@echo "Logs:   \$${XDG_STATE_HOME:-\$$HOME/.local/state}/audio-utils/"
	@echo "Config: \$${XDG_CONFIG_HOME:-\$$HOME/.config}/audio-utils/config"

check-lib:
	$(SHELLCHECK) $(LIB_SCRIPTS)

check-tests:
	$(SHELLCHECK) $(TEST_SCRIPTS)

test:
	bash tests/run.sh -j $(JOBS) unit smoke

test-functional:
	bash tests/run.sh -j $(JOBS) functional

test-all:
	bash tests/run.sh -j $(JOBS)

coverage:
	bash scripts/coverage-audit.sh

new-util:
	@[ -n "$(CATEGORY)" ] && [ -n "$(NAME)" ] \
		|| { echo "usage: make new-util CATEGORY=x NAME=y [EXT=flac]"; exit 2; }
	bash scripts/new-tool.sh util "$(CATEGORY)" "$(NAME)" $(EXT)

new-converter:
	@[ -n "$(NAME)" ] || { echo "usage: make new-converter NAME=x-to-y"; exit 2; }
	bash scripts/new-tool.sh converter "$(NAME)"

# Single job pool over all tools (avoids oversubscribe from nested -j pools).
check-tools:
	@JOBS=$(JOBS) $(RUN_PARALLEL) -j $(JOBS) $(TOOLS)

check-conversion:
	@JOBS=$(JOBS) $(RUN_PARALLEL) -j $(JOBS) $(CONVERSION)

check-util:
	@JOBS=$(JOBS) $(RUN_PARALLEL) -j $(JOBS) $(UTIL)

# Lib + tests first (fast), then one parallel pool across every tool.
check: check-lib check-tests check-tools

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
