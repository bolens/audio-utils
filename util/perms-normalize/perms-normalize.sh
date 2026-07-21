#!/usr/bin/env bash
# Report (or fix) file / directory permission modes across the library.
#
# Usage:
#   perms-normalize.sh DIR [DIR ...]
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#   --apply             chmod non-conforming files/dirs (default: report-only)
#   --file-mode=NNN     Target file mode (default: 644)
#   --dir-mode=NNN      Target directory mode (default: 755)
#
# -d / -D / -y rejected. Ownership is not touched.
# Exit codes: 0 clean, 1 non-conforming/failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=14
# shellcheck source=../../lib/cli.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/cli.sh"
audio_utils_cli_run "$@"
