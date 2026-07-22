# Shared per-tool Makefile fragment.
#
# Before include, set:
#   TOOL            — e.g. flac-to-mp3
#   SCRIPTS         — shellcheck targets
#   FIND_SCRIPT     — e.g. find-flac-dirs.sh (optional; omit find-dirs if empty)
#   WORKDIR_GLOB    — e.g. .flac2mp3.*
# Optional:
#   HELP_EXTRA      — extra help lines
#   CONVERT         — default ./convert-all.sh
#   EXTRA_PHONY     — additional .PHONY targets
#   HAS_CONVERT_VERBOSE / HAS_CONVERT_CLEAN / HAS_RETAG — set to 1 to enable
#   HAS_DELETE      — set to 0 to omit convert-delete / -D targets (default 1)
#   HAS_DELETE_EXISTING — set to 0 to omit only the -D / $(DELETE_TARGET) rules
#                     while keeping convert-delete (-d). Defaults to HAS_DELETE.
#   DELETE_TARGET   — make target name for -D (default delete-sources)

# -x follows sources for symbol resolution; omit -a so each tool does not
# re-lint the entire shared lib/ tree (checked once from the root Makefile).
SHELLCHECK ?= shellcheck -x
CONVERT ?= ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)
DELETE_TARGET ?= delete-sources
HAS_DELETE ?= 1
HAS_DELETE_EXISTING ?= $(HAS_DELETE)

.PHONY: help check test dry-run convert convert-quiet clean clean-tmp \
	$(EXTRA_PHONY)

help:
	@echo -n "$(TOOL): make check | test | convert | convert-quiet"
ifeq ($(HAS_DELETE),1)
	@echo -n " | convert-delete"
endif
ifeq ($(HAS_DELETE_EXISTING),1)
	@echo -n " | $(DELETE_TARGET)"
endif
	@echo
	@echo "  make dry-run / clean / clean-tmp"
ifneq ($(FIND_SCRIPT),)
	@echo "  make find-dirs   (needs AUDIO_UTILS_ROOTS or ROOTS=)"
endif
ifdef HELP_EXTRA
	@echo "$(HELP_EXTRA)"
endif

check:
	$(SHELLCHECK) $(SCRIPTS)

# Repo test suite narrowed to this tool: smoke checks plus any unit or
# functional file whose name mentions the tool.
test:
	bash "$(AU_ROOT)/tests/run.sh" --tool "$(TOOL)"

ifneq ($(FIND_SCRIPT),)
.PHONY: find-dirs
find-dirs:
	@if [ -z "$(ROOTS)" ] && [ -z "$(AUDIO_UTILS_ROOTS)" ] && [ -z "$(WAV2FLAC_ROOTS)" ]; then \
		echo "Set AUDIO_UTILS_ROOTS or ROOTS="; exit 1; \
	fi
	./$(FIND_SCRIPT) $(ROOTS)
endif

dry-run:
	$(CONVERT) -n $(ARGS)

convert:
	$(CONVERT) $(ARGS)

convert-quiet:
	$(CONVERT) -q $(ARGS)

ifeq ($(HAS_DELETE),1)
.PHONY: convert-delete
convert-delete:
	$(CONVERT) -d $(ARGS)
endif

ifeq ($(HAS_DELETE_EXISTING),1)
.PHONY: $(DELETE_TARGET) $(DELETE_TARGET)-dry
$(DELETE_TARGET)-dry:
	$(CONVERT) -D -n $(ARGS)

$(DELETE_TARGET):
	$(CONVERT) -D $(ARGS)
endif

ifeq ($(HAS_CONVERT_VERBOSE),1)
.PHONY: convert-verbose
convert-verbose:
	$(CONVERT) -v $(ARGS)
endif

ifeq ($(HAS_CONVERT_CLEAN),1)
.PHONY: convert-clean
convert-clean:
	$(CONVERT) -c $(ARGS)
endif

ifeq ($(HAS_RETAG),1)
.PHONY: retag retag-dry
retag-dry:
	$(CONVERT) -R -n $(ARGS)
retag:
	$(CONVERT) -R $(ARGS)
endif

clean:
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/$(TOOL)"; \
	rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; \
	$(CLEAN_EXTRA) \
	echo "cleaned $$state"

clean-tmp:
	@roots="$(ROOTS)"; \
	[ -n "$$roots" ] || roots="$(AUDIO_UTILS_ROOTS)"; \
	[ -n "$$roots" ] || roots="$(WAV2FLAC_ROOTS)"; \
	[ -n "$$roots" ] || { echo "Set AUDIO_UTILS_ROOTS or ROOTS="; exit 1; }; \
	find $$roots -type d -name '$(WORKDIR_GLOB)' -print0 2>/dev/null | xargs -0 -r rm -rf --; \
	echo done
