#!/usr/bin/env bash
# tags-lookup — AcoustID fingerprint → MusicBrainz recording-id report.
#
# The only audio-utils tool that touches the network, and only when an
# AcoustID client key is supplied. See docs/enrichment.md.

AU_TOOL_NAME="${AU_TOOL_NAME:-tags-lookup}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=tagslkp
AU_SUCCESS_COLUMNS='timestamp,file,status,audio_md5,file_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/media/audio_exts.sh
source "$_AU_ROOT/lib/media/audio_exts.sh"
AU_SOURCE_EXTS=$AU_AUDIO_EXTS_DEFAULT
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

ACOUSTID_CLIENT_KEY="${ACOUSTID_CLIENT_KEY:-}"
LOOKUP_DELAY="${LOOKUP_DELAY:-0.4}"

plugin_consume_arg() {
  case "${1:-}" in
    --client-key=*)
      ACOUSTID_CLIENT_KEY="${1#--client-key=}"; AU_CONSUMED=1
      export AU_CONSUMED ACOUSTID_CLIENT_KEY; return 0 ;;
    --client-key)
      [[ -n "${2:-}" ]] || { echo "Error: --client-key needs KEY" >&2; return 1; }
      ACOUSTID_CLIENT_KEY=$2; AU_CONSUMED=2
      export AU_CONSUMED ACOUSTID_CLIENT_KEY; return 0 ;;
    --delay=*)
      LOOKUP_DELAY="${1#--delay=}"; AU_CONSUMED=1
      export AU_CONSUMED LOOKUP_DELAY; return 0 ;;
    --delay)
      [[ -n "${2:-}" ]] || { echo "Error: --delay needs SEC" >&2; return 1; }
      LOOKUP_DELAY=$2; AU_CONSUMED=2
      export AU_CONSUMED LOOKUP_DELAY; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: tags-lookup is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: tags-lookup is read-only; -y is not supported" >&2
    return 1
  fi
  if [[ -z "$ACOUSTID_CLIENT_KEY" ]]; then
    cat >&2 <<'EOF'
Error: AcoustID client key required (network lookups are opt-in).

  Register a free application key at https://acoustid.org/new-application,
  then pass --client-key=KEY or set ACOUSTID_CLIENT_KEY.
EOF
    return 1
  fi
  if ! [[ "$LOOKUP_DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: --delay must be a number (got: $LOOKUP_DELAY)" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds fpcalc curl flock
  command -v jq >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  log_always "mode:      AcoustID lookup report (network; delay=${LOOKUP_DELAY}s)"
  if ! command -v jq >/dev/null 2>&1; then
    log_always "note:      jq not found; using coarse JSON parsing"
  fi
}

plugin_export_env() {
  export ACOUSTID_CLIENT_KEY LOOKUP_DELAY AU_CLEANUP_SKIP AU_SOURCE_EXTS
  [[ -z "${ACOUSTID_API_URL:-}" ]] || export ACOUSTID_API_URL
}
