#!/usr/bin/env bash
# Thin CLI bootstrap for driver-based converters.
#
# In a tool entrypoint (after the # Usage comment block):
#
#   set -euo pipefail
#   AU_USAGE_START=2
#   AU_USAGE_END=11
#   # shellcheck source=../lib/cli.sh
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/cli.sh"
#   audio_utils_cli_run "$@"
#
# Optional: AU_USAGE_FILE (defaults to the calling script).

audio_utils_cli_run() {
  local cli="${BASH_SOURCE[1]:-}"
  local script_dir lib_dir

  [[ -n "$cli" ]] || {
    echo "audio_utils_cli_run: must be called from a tool entrypoint" >&2
    exit 2
  }

  script_dir=$(cd "$(dirname -- "$cli")" && pwd)
  lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

  AU_USAGE_FILE="${AU_USAGE_FILE:-$cli}"
  : "${AU_USAGE_START:?AU_USAGE_START required before audio_utils_cli_run}"
  : "${AU_USAGE_END:?AU_USAGE_END required before audio_utils_cli_run}"
  export AU_USAGE_FILE AU_USAGE_START AU_USAGE_END

  # shellcheck source=/dev/null
  source "${script_dir}/lib/plugin.sh"
  # shellcheck source=driver.sh
  source "${lib_dir}/driver.sh"

  audio_utils_load_config
  audio_utils_run "$@"
}
