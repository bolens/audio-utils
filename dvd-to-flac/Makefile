SHELLCHECK = shellcheck -x -a
SCRIPTS = dvd-to-flac.sh find-video_ts-dirs.sh convert-all.sh lib/*.sh
CONVERT = ./convert-all.sh
ARGS ?=
ROOTS ?= $(AUDIO_UTILS_ROOTS)
.PHONY: help check find-dirs dry-run convert convert-quiet clean clean-tmp
help:
	@echo "dvd-to-flac: make check | convert (VIDEO_TS dirs)"
check:
	$(SHELLCHECK) $(SCRIPTS)
find-dirs:
	@if [ -z "$(ROOTS)" ] && [ -z "$(AUDIO_UTILS_ROOTS)" ]; then echo "Set AUDIO_UTILS_ROOTS"; exit 1; fi
	./find-video_ts-dirs.sh $(ROOTS)
dry-run:
	$(CONVERT) -n $(ARGS)
convert:
	$(CONVERT) $(ARGS)
convert-quiet:
	$(CONVERT) -q $(ARGS)
clean:
	@state="$${XDG_STATE_HOME:-$$HOME/.local/state}/audio-utils/dvd-to-flac"; rm -f "$$state/failures.log" "$$state/success.csv" "$$state/success.jsonl"; echo cleaned
clean-tmp:
	@roots="$(ROOTS)"; [ -n "$$roots" ] || roots="$(AUDIO_UTILS_ROOTS)"; 	[ -n "$$roots" ] || { echo "Set AUDIO_UTILS_ROOTS"; exit 1; }; 	find $$roots -type d -name '.dvd2flac.*' -print0 2>/dev/null | xargs -0 -r rm -rf --; echo done
