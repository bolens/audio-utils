# flac-to-mp3 — common targets

SHELLCHECK = shellcheck -x -a
SCRIPTS = flac-to-mp3.sh find-flac-dirs.sh convert-all.sh lib/*.sh
CONVERT = ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)

.PHONY: help check find-dirs \
	dry-run convert convert-quiet convert-verbose convert-delete \
	delete-flacs delete-flacs-dry \
	clean clean-tmp

help:
	@echo "Targets:"
	@echo "  make check / find-dirs / dry-run / convert / convert-quiet"
	@echo "  make convert-delete     Convert then delete FLACs (-d)"
	@echo "  make delete-flacs[-dry] Cleanup (-D)"
	@echo "  make clean / clean-tmp"
	@echo "Quality: make convert ARGS='-Q v0'   (default v0; also v2, 320, 192)"
	@echo "Env: AUDIO_UTILS_ROOTS=…  FLAC2MP3_QUALITY=v0"

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
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/flac-to-mp3"; \
	rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; \
	echo "cleaned $$state"

clean-tmp:
	@roots="$(ROOTS)"; \
	if [ -z "$$roots" ]; then roots="$(AUDIO_UTILS_ROOTS)"; fi; \
	if [ -z "$$roots" ]; then \
		echo "Set AUDIO_UTILS_ROOTS or ROOTS="; exit 1; \
	fi; \
	find $$roots -type d -name '.flac2mp3.*' -print0 2>/dev/null | xargs -0 -r rm -rf --; \
	echo "done"
