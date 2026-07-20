# wav-to-flac — common targets
#
# Extra flags: make convert ARGS='-j 4 -S run.jsonl'
# Library roots (find / clean-tmp): set AUDIO_UTILS_ROOTS or WAV2FLAC_ROOTS,
# or pass ROOTS='~/Music ~/Downloads' for clean-tmp / find-dirs.

SHELLCHECK = shellcheck -x -a
SCRIPTS = wav-to-flac.sh find-wav-dirs.sh convert-all.sh lib/*.sh
CONVERT = ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)

.PHONY: help check find-dirs \
	dry-run convert convert-quiet convert-verbose convert-delete convert-clean \
	delete-wavs delete-wavs-dry \
	retag retag-dry \
	clean clean-tmp

help:
	@echo "Targets:"
	@echo "  make check              Run shellcheck on all scripts"
	@echo "  make find-dirs          List dirs that contain WAVs (needs ROOTS or AUDIO_UTILS_ROOTS)"
	@echo ""
	@echo "  make dry-run            Preview convert (-n)"
	@echo "  make convert            Convert all discovered WAV dirs"
	@echo "  make convert-quiet      Convert quietly (-q)"
	@echo "  make convert-verbose    Convert with remux/prep notes (-v)"
	@echo "  make convert-delete     Convert then delete WAVs (-d)"
	@echo "  make convert-clean      Convert then replace WAVs with FLAC decode (-c)"
	@echo ""
	@echo "  make delete-wavs-dry    Preview deleting WAVs that already have FLACs (-D -n)"
	@echo "  make delete-wavs        Delete WAVs that already have valid FLACs (-D)"
	@echo ""
	@echo "  make retag-dry          Preview retag of existing FLACs (-R -n)"
	@echo "  make retag              Retag existing FLACs from WAVs (-R)"
	@echo ""
	@echo "  make clean              Remove local success/failure logs"
	@echo "  make clean-tmp          Remove orphan .wav2flac.* under ROOTS"
	@echo ""
	@echo "Env:  AUDIO_UTILS_ROOTS='/path/Music /path/Downloads'"
	@echo "Extra flags:  make convert ARGS='-j 4 -S out.jsonl'"
	@echo "clean-tmp:    make clean-tmp ROOTS='/path/Music'"

check:
	$(SHELLCHECK) $(SCRIPTS)

find-dirs:
	@if [ -z "$(ROOTS)" ] && [ -z "$(AUDIO_UTILS_ROOTS)" ] && [ -z "$(WAV2FLAC_ROOTS)" ]; then \
		echo "Set AUDIO_UTILS_ROOTS or: make find-dirs ROOTS='/path/Music'"; exit 1; \
	fi
	./find-wav-dirs.sh $(ROOTS)

# --- convert ---------------------------------------------------------------

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

# --- cleanup / retag -------------------------------------------------------

delete-wavs-dry:
	$(CONVERT) -D -n $(ARGS)

delete-wavs:
	$(CONVERT) -D $(ARGS)

retag-dry:
	$(CONVERT) -R -n $(ARGS)

retag:
	$(CONVERT) -R $(ARGS)

# --- housekeeping ----------------------------------------------------------

clean:
	rm -f wav-to-flac-failures.log wav-to-flac-success.csv wav-to-flac-success.jsonl
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/wav-to-flac"; \
	rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; \
	echo "cleaned cwd logs + $$state"

clean-tmp:
	@roots="$(ROOTS)"; \
	if [ -z "$$roots" ]; then roots="$(AUDIO_UTILS_ROOTS)"; fi; \
	if [ -z "$$roots" ]; then roots="$(WAV2FLAC_ROOTS)"; fi; \
	if [ -z "$$roots" ]; then \
		echo "Set AUDIO_UTILS_ROOTS or: make clean-tmp ROOTS='/path/Music /path/Downloads'"; \
		exit 1; \
	fi; \
	echo "Sweeping orphan .wav2flac.* under: $$roots"; \
	# shellcheck disable=SC2086
	find $$roots -type d -name '.wav2flac.*' -print0 2>/dev/null \
		| xargs -0 -r rm -rf --; \
	echo "done"
