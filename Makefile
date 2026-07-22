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
	check-tests test test-functional test-all test-ci clean-tests coverage new-util \
	new-converter ape-install ape-update ape-status ape-uninstall \
	keyfinder-install keyfinder-status \
	$(addsuffix -%,$(TOOLS))

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
	@echo "  make test-ci               run the suite in a CI-like container (docker/podman)"
	@echo "  make test K=PATTERN        narrow any test target to matching files"
	@echo "  make clean-tests           remove fixture cache + stray test sandboxes"
	@echo "  make coverage              audit test coverage vs the 90% goal"
	@echo "  make -C TOOLDIR test       run smoke + matching tests for one tool"
	@echo "  make new-util CATEGORY=x NAME=y      scaffold util/x/y"
	@echo "  make new-converter NAME=x-to-y       scaffold conversion/x-to-y"
	@echo "  make ape-install           build + install Monkey's Audio codec (mac)"
	@echo "  make ape-update            update the codec to the latest release"
	@echo "  make ape-status            installed codec version + integrity"
	@echo "  make ape-uninstall         remove the codec (manifest-driven)"
	@echo "  make keyfinder-install     build + install keyfinder-cli (best effort)"
	@echo "  make keyfinder-status      show keyfinder-cli install path"
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

# Optional K=PATTERN narrows to matching test files (tests/run.sh -k).
test:
	bash tests/run.sh -j $(JOBS) $(if $(K),-k $(K)) unit smoke

test-functional:
	bash tests/run.sh -j $(JOBS) $(if $(K),-k $(K)) functional

test-all:
	bash tests/run.sh -j $(JOBS) $(if $(K),-k $(K))

# CI parity: full suite in an ubuntu:24.04 container (the runner's distro,
# with its older ffmpeg). FFMPEG=latest exercises the upstream-ffmpeg leg.
test-ci:
	bash scripts/test-ci.sh $(if $(FFMPEG),--ffmpeg $(FFMPEG)) $(if $(K),-k $(K))

clean-tests:
	rm -rf tests/.cache .tmp-auth-test .tmp-util-test.* .tmp-codec-*
	@echo "removed test fixture cache and stray test sandboxes"

coverage:
	bash scripts/coverage-audit.sh

# Monkey's Audio (APE) codec management — no official Linux build exists.
# Extra flags (e.g. --version, --sha256, --force): APE_FLAGS="..."
ape-install:
	bash scripts/ape-codec.sh install $(APE_FLAGS)

ape-update:
	bash scripts/ape-codec.sh update $(APE_FLAGS)

ape-status:
	bash scripts/ape-codec.sh status

ape-uninstall:
	bash scripts/ape-codec.sh uninstall $(APE_FLAGS)

keyfinder-install:
	bash scripts/keyfinder-cli.sh install $(KEYFINDER_FLAGS)

keyfinder-status:
	bash scripts/keyfinder-cli.sh status $(KEYFINDER_FLAGS)

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
