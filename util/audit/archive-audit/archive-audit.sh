#!/usr/bin/env bash
# Audit preservation packages (checksums, provenance, FLAC, signatures, PAR2).
#
# Usage:
#   archive-audit.sh DIR [DIR ...]
#
# Options:
#   --quick               Checksums/signature only; skip semantic/decode audit
#   --public-key KEY      Minisign public key
#   --snapshot-dir DIR    Atomically write one current snapshot per package
#   --baseline-dir DIR    Fail when current package differs from its snapshot
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Read-only package audit: -d / -D / -y rejected.
# Exit codes: 0 clean, 1 issues/drift, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=16
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=../../../lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
