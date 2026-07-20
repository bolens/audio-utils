# aiff-to-flac

SHELLCHECK = shellcheck -x -a
SCRIPTS = aiff-to-flac.sh find-aiff-dirs.sh convert-all.sh lib/*.sh
CONVERT = ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)

.PHONY: help check find-dirs dry-run convert convert-quiet convert-verbose \
	convert-delete convert-clean delete-aiffs delete-aiffs-dry retag retag-dry clean clean-tmp

help:
	@echo "aiff-to-flac: make check | convert | convert-delete | convert-clean | retag | delete-aiffs"

check:
	$(SHELLCHECK) $(SCRIPTS)

find-dirs:
	@if [ -z "$(ROOTS)" ] && [ -z "$(AUDIO_UTILS_ROOTS)" ]; then echo "Set AUDIO_UTILS_ROOTS"; exit 1; fi
	./find-aiff-dirs.sh $(ROOTS)

dry-run:
	$(CONVERT) -n $(ARGS)
convert:
	$(CONVERT) $(ARGS)
convert-quiet:
	$(CONVERT) -q $(ARGS)
convert-verbose:
	$(CONVERT) -v $(ARGS)
convert-delete:
	$(CONVERT) -d $(ARGS)
convert-clean:
	$(CONVERT) -c $(ARGS)
delete-aiffs-dry:
	$(CONVERT) -D -n $(ARGS)
delete-aiffs:
	$(CONVERT) -D $(ARGS)
retag-dry:
	$(CONVERT) -R -n $(ARGS)
retag:
	$(CONVERT) -R $(ARGS)

clean:
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/aiff-to-flac"; \
	rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; echo "cleaned $$state"

clean-tmp:
	@roots="$(ROOTS)"; [ -n "$$roots" ] || roots="$(AUDIO_UTILS_ROOTS)"; \
	[ -n "$$roots" ] || { echo "Set AUDIO_UTILS_ROOTS"; exit 1; }; \
	find $$roots -type d -name '.aiff2flac.*' -print0 2>/dev/null | xargs -0 -r rm -rf --; echo done
