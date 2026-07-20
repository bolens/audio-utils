SHELLCHECK = shellcheck -x -a
SCRIPTS = cue-to-flac.sh find-cue-dirs.sh convert-all.sh lib/*.sh
CONVERT = ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)
.PHONY: help check find-dirs dry-run convert convert-quiet convert-delete delete-sources delete-sources-dry clean clean-tmp
help:
	@echo "cue-to-flac: make check | convert | convert-delete | delete-sources"
check:
	$(SHELLCHECK) $(SCRIPTS)
find-dirs:
	@if [ -z "$(ROOTS)" ] && [ -z "$(AUDIO_UTILS_ROOTS)" ]; then echo "Set AUDIO_UTILS_ROOTS"; exit 1; fi
	./find-cue-dirs.sh $(ROOTS)
dry-run:
	$(CONVERT) -n $(ARGS)
convert:
	$(CONVERT) $(ARGS)
convert-quiet:
	$(CONVERT) -q $(ARGS)
convert-delete:
	$(CONVERT) -d $(ARGS)
delete-sources-dry:
	$(CONVERT) -D -n $(ARGS)
delete-sources:
	$(CONVERT) -D $(ARGS)
clean:
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/cue-to-flac"; rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; echo cleaned
clean-tmp:
	@roots="$(ROOTS)"; [ -n "$$roots" ] || roots="$(AUDIO_UTILS_ROOTS)"; \
	[ -n "$$roots" ] || { echo "Set AUDIO_UTILS_ROOTS"; exit 1; }; \
	find $$roots -type d -name '.cue2flac.*' -print0 2>/dev/null | xargs -0 -r rm -rf --; echo done
