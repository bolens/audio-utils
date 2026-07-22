#!/usr/bin/env bash
# Convert WAV files to FLAC in one or more directories, with verification.
#
# Verification (per file):
#   0. Remux every WAV to a clean PCM temp (float->s24 with peak/scale checks;
#      integer->same codec). Dual remux + sample-count checks. Always enforce
#      prep audio MD5 == FLAC audio MD5 end-to-end.
#   1. Encode prep->FLAC twice; SHA-256 of both FLACs must match
#   2. Decode FLAC->WAV, re-encode->FLAC; SHA-256 must match
#   3. Compare ffmpeg audio MD5 of FLAC vs decoded WAV
#   4. Run flac -t integrity test
#   5. Copy tags/cover from source WAV onto FLAC (audio stream untouched)
# Existing FLACs that pass flac -t are skipped; corrupt ones are reconverted.
# Temps live next to the destination (atomic mv); cleaned on EXIT/INT/TERM.
# Failures -> failure log; successes -> success CSV/JSONL log.
#
# Layout: shared lib/cli + pcm_to_flac + driver; local lib/plugin.sh.
#
# Usage:
#   wav-to-flac.sh DIR [DIR ...]
#   wav-to-flac.sh -f dirs.txt
#   find-wav-dirs.sh | wav-to-flac.sh
#   convert-all.sh [wav-to-flac options...]
#
# Options:
#   -f FILE     Read directory list from FILE (one path per line)
#   -d          Delete WAV after successful conversion + verification
#   -D          Cleanup only: delete WAVs that already have a sibling FLAC
#   -c          Replace WAV with a clean decode from the verified FLAC
#   -R          Retag only: copy metadata/cover onto existing valid FLACs
#   -L FILE     Failure log path (default: $XDG_STATE_HOME/audio-utils/wav-to-flac/failures.log)
#   -S FILE     Success log CSV or .jsonl (default: …/success.csv under same state dir)
#   -n          Dry run (print actions only)
#   -y          Overwrite existing FLACs even if flac -t passes
#   -j N        Parallel jobs (default: max(1, nproc/2))
#   -q          Quiet (progress + failures + summary only)
#   -v          Verbose (remux/prep notes, peak scaling, e2e details)
#   -h          Show help
#   --version   Print version and exit
#
# Exit codes: 0 all ok, 1 some conversions failed, 2 usage/config/deps error


set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=41
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
