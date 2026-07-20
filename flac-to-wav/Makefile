# flac-to-wav — common targets
#
# Extra flags: make convert ARGS='-j 4 -S run.jsonl'
# Library roots: AUDIO_UTILS_ROOTS or ROOTS='…'

SHELLCHECK = shellcheck -x -a
SCRIPTS = flac-to-wav.sh find-flac-dirs.sh convert-all.sh lib/*.sh
CONVERT = ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)

.PHONY: help check find-dirs \
	dry-run convert convert-quiet convert-verbose convert-delete \
	delete-flacs delete-flacs-dry \
	clean clean-tmp

help:
	@echo "Targets:"
	@echo "  make check              shellcheck"
	@echo "  make find-dirs          List dirs with FLACs"
	@echo "  make dry-run / convert / convert-quiet / convert-verbose"
	@echo "  make convert-delete     Convert then delete FLACs (-d)"
	@echo "  make delete-flacs[-dry] Cleanup FLACs with sibling WAVs (-D)"
	@echo "  make clean / clean-tmp"
	@echo "Env: AUDIO_UTILS_ROOTS='/path/Music'"

check:
	$(SHELLCHECK) $(SCRIPTS)

find-dirs:
	@if [ -z "$(ROOTS)" ] && [ -z "$(AUDIO_UTILS_ROOTS)" ]; then \
		echo "Set AUDIO_UTILS_ROOTS or ROOTS="; exit 1; \
	fi
	./find-flac-dirs.sh $(ROOTS)

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

delete-flacs-dry:
	$(CONVERT) -D -n $(ARGS)

delete-flacs:
	$(CONVERT) -D $(ARGS)

clean:
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/flac-to-wav"; \
	rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; \
	echo "cleaned $$state"

clean-tmp:
	@roots="$(ROOTS)"; \
	if [ -z "$$roots" ]; then roots="$(AUDIO_UTILS_ROOTS)"; fi; \
	if [ -z "$$roots" ]; then \
		echo "Set AUDIO_UTILS_ROOTS or ROOTS="; exit 1; \
	fi; \
	find $$roots -type d -name '.flac2wav.*' -print0 2>/dev/null | xargs -0 -r rm -rf --; \
	echo "done"
