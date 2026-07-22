#!/usr/bin/env bash
# playlist-smart — build a filtered .m3u from tag queries across roots.

AU_TOOL_NAME="${AU_TOOL_NAME:-playlist-smart}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=m3u
AU_DISK_FACTOR=1
AU_WORKDIR_PREFIX=plsmart
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
AU_SOURCE_EXTS="$AU_AUDIO_EXTS_DEFAULT $AU_AUDIO_EXTS_PCM $AU_AUDIO_EXTS_ARCHIVE"
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

PLSMART_OUT="${PLSMART_OUT:-}"
PLSMART_GENRE="${PLSMART_GENRE:-}"
PLSMART_ARTIST="${PLSMART_ARTIST:-}"
PLSMART_KEY="${PLSMART_KEY:-}"
PLSMART_BPM_MIN="${PLSMART_BPM_MIN:-}"
PLSMART_BPM_MAX="${PLSMART_BPM_MAX:-}"
PLSMART_RG_MAX="${PLSMART_RG_MAX:-}"
PLSMART_RELATIVE="${PLSMART_RELATIVE:-0}"

plugin_consume_arg() {
  case "${1:-}" in
    --out=*)
      PLSMART_OUT="${1#--out=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_OUT; return 0 ;;
    --out)
      [[ -n "${2:-}" ]] || { echo "Error: --out needs a path" >&2; return 1; }
      PLSMART_OUT=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_OUT; return 0 ;;
    --genre=*)
      PLSMART_GENRE="${1#--genre=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_GENRE; return 0 ;;
    --genre)
      [[ -n "${2:-}" ]] || { echo "Error: --genre needs a value" >&2; return 1; }
      PLSMART_GENRE=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_GENRE; return 0 ;;
    --artist=*)
      PLSMART_ARTIST="${1#--artist=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_ARTIST; return 0 ;;
    --artist)
      [[ -n "${2:-}" ]] || { echo "Error: --artist needs a value" >&2; return 1; }
      PLSMART_ARTIST=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_ARTIST; return 0 ;;
    --key=*)
      PLSMART_KEY="${1#--key=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_KEY; return 0 ;;
    --key)
      [[ -n "${2:-}" ]] || { echo "Error: --key needs a value" >&2; return 1; }
      PLSMART_KEY=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_KEY; return 0 ;;
    --bpm-min=*)
      PLSMART_BPM_MIN="${1#--bpm-min=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_BPM_MIN; return 0 ;;
    --bpm-min)
      [[ -n "${2:-}" ]] || { echo "Error: --bpm-min needs a value" >&2; return 1; }
      PLSMART_BPM_MIN=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_BPM_MIN; return 0 ;;
    --bpm-max=*)
      PLSMART_BPM_MAX="${1#--bpm-max=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_BPM_MAX; return 0 ;;
    --bpm-max)
      [[ -n "${2:-}" ]] || { echo "Error: --bpm-max needs a value" >&2; return 1; }
      PLSMART_BPM_MAX=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_BPM_MAX; return 0 ;;
    --rg-max=*)
      PLSMART_RG_MAX="${1#--rg-max=}"; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_RG_MAX; return 0 ;;
    --rg-max)
      [[ -n "${2:-}" ]] || { echo "Error: --rg-max needs a value" >&2; return 1; }
      PLSMART_RG_MAX=$2; AU_CONSUMED=2
      export AU_CONSUMED PLSMART_RG_MAX; return 0 ;;
    --relative)
      PLSMART_RELATIVE=1; AU_CONSUMED=1
      export AU_CONSUMED PLSMART_RELATIVE; return 0 ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: playlist-smart does not support -d/-D" >&2
    return 1
  fi
  if [[ -z "${PLSMART_OUT}" ]]; then
    echo "Error: --out PATH is required (destination .m3u)" >&2
    return 1
  fi
  if [[ -z "${PLSMART_GENRE}${PLSMART_ARTIST}${PLSMART_KEY}${PLSMART_BPM_MIN}${PLSMART_BPM_MAX}${PLSMART_RG_MAX}" ]]; then
    echo "Error: at least one filter required (--genre/--artist/--key/--bpm-min/--bpm-max/--rg-max)" >&2
    return 1
  fi
  for v in PLSMART_BPM_MIN PLSMART_BPM_MAX; do
    local val=${!v}
    if [[ -n "$val" && ! "$val" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "Error: $v must be numeric (got $val)" >&2
      return 1
    fi
  done
  if [[ -n "${PLSMART_RG_MAX}" && ! "${PLSMART_RG_MAX}" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: --rg-max must be numeric (got ${PLSMART_RG_MAX})" >&2
    return 1
  fi
  export PLSMART_OUT PLSMART_GENRE PLSMART_ARTIST PLSMART_KEY \
    PLSMART_BPM_MIN PLSMART_BPM_MAX PLSMART_RG_MAX PLSMART_RELATIVE
  return 0
}

plugin_require_deps() {
  require_cmds flock
  command -v ffprobe >/dev/null 2>&1 || true
  command -v metaflac >/dev/null 2>&1 || true
}

plugin_banner_extra() {
  log_always "out:       ${PLSMART_OUT}"
  local f=()
  [[ -n "${PLSMART_GENRE}" ]] && f+=("genre=${PLSMART_GENRE}")
  [[ -n "${PLSMART_ARTIST}" ]] && f+=("artist=${PLSMART_ARTIST}")
  [[ -n "${PLSMART_KEY}" ]] && f+=("key=${PLSMART_KEY}")
  [[ -n "${PLSMART_BPM_MIN}" ]] && f+=("bpm>=${PLSMART_BPM_MIN}")
  [[ -n "${PLSMART_BPM_MAX}" ]] && f+=("bpm<=${PLSMART_BPM_MAX}")
  [[ -n "${PLSMART_RG_MAX}" ]] && f+=("rg<=${PLSMART_RG_MAX}")
  log_always "filters:   ${f[*]}"
}

plugin_export_env() {
  if [[ -z "${AU_PLSMART_STATE:-}" ]]; then
    AU_PLSMART_STATE=$(audio_utils_mktemp_d "plsmart.XXXXXX")
    register_tmpdir "$AU_PLSMART_STATE"
  fi
  export AU_PLSMART_STATE AU_CLEANUP_SKIP AU_SOURCE_EXTS \
    PLSMART_OUT PLSMART_GENRE PLSMART_ARTIST PLSMART_KEY \
    PLSMART_BPM_MIN PLSMART_BPM_MAX PLSMART_RG_MAX PLSMART_RELATIVE
}

plugin_finalize() {
  local matches="${AU_PLSMART_STATE:-}/matches.tsv"
  local out=${PLSMART_OUT:-}
  local n=0 mode=absolute basedir
  local US=$'\x1f'

  [[ -n "$out" ]] || return 0
  [[ -f "$matches" ]] || : >"$matches"
  n=$(wc -l <"$matches" | tr -d ' ')

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_always "would write $n matches -> $out"
    return 0
  fi

  if [[ "${PLSMART_RELATIVE:-0}" -eq 1 ]]; then
    mode=relative
    basedir=$(cd -- "$(dirname -- "$out")" && pwd) || basedir=$(dirname -- "$out")
  else
    basedir=""
  fi

  local entries
  entries=$(audio_utils_mktemp "plsmart.XXXXXX") || {
    log_err "Error: cannot create temp for playlist-smart"
    return 0
  }

  # matches.tsv: path<TAB>title<TAB>duration
  while IFS=$'\t' read -r path title dur || [[ -n "$path" ]]; do
    [[ -n "$path" ]] || continue
    printf '%s%s%s%s%s\n' "$path" "$US" "${title:-}" "$US" "${dur:--1}"
  done <"$matches" | LC_ALL=C sort -u >"$entries"

  n=$(wc -l <"$entries" | tr -d ' ')
  if ((n == 0)); then
    log_always "No matches; not writing $out"
    rm -f -- "$entries"
    return 0
  fi

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    log_err "Error: $out exists (pass -y to overwrite)"
    rm -f -- "$entries"
    return 0
  fi

  mkdir -p -- "$(dirname -- "$out")" 2>/dev/null || true
  if playlist_write m3u "$out" "${basedir:-$(dirname -- "$out")}" "$mode" <"$entries"; then
    log_always "Wrote $n tracks -> $out"
  else
    log_err "Error: failed writing $out"
  fi
  rm -f -- "$entries"
}
