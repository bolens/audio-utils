SHELLCHECK = shellcheck -x
SCRIPTS = cdda-to-flac.sh lib/*.sh
.PHONY: help check
help:
	@echo "cdda-to-flac: make check"
	@echo "  ./cdda-to-flac.sh [/dev/sr0] [-o OUTDIR]"
check:
	$(SHELLCHECK) $(SCRIPTS)
