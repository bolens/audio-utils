#!/usr/bin/env bash
# flac-inventory plugin — library stats report.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-inventory}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacinv
AU_SUCCESS_COLUMNS='timestamp,flac,mode,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-inventory is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: flac-inventory is read-only; -y is not supported" >&2
    return 1
  fi
  return 0
}

plugin_require_deps() {
  require_cmds flac metaflac ffmpeg ffprobe flock
}

plugin_banner_extra() {
  log_always "mode:      inventory (rate/depth/RG/art/bytes)"
}

plugin_export_env() {
  if [[ -z "${AU_INV_STATE:-}" ]]; then
    AU_INV_STATE=$(audio_utils_mktemp_d "inv.XXXXXX")
    register_tmpdir "$AU_INV_STATE"
  fi
  AU_INV_REPORT="${AU_INV_REPORT:-$(audio_utils_state_dir_path "$AU_TOOL_NAME")/inventory-report.txt}"
  export AU_INV_STATE AU_INV_REPORT AU_CLEANUP_SKIP
}

plugin_finalize() {
  local rows="${AU_INV_STATE:-}/rows.tsv"
  local report="${AU_INV_REPORT:-}"
  local n=0
  [[ -f "$rows" ]] || {
    log_always "Inventory: no rows collected"
    return 0
  }
  n=$(wc -l <"$rows" | tr -d ' ')
  mkdir -p -- "$(dirname -- "$report")" 2>/dev/null || true
  {
    echo "flac-inventory report"
    echo "files: $n"
    echo
    echo "=== sample rate ==="
    awk -F'\t' '{c[$2]++} END {for (k in c) printf "  %s Hz: %d\n", k, c[k]}' "$rows" | LC_ALL=C sort
    echo
    echo "=== bit depth ==="
    awk -F'\t' '{c[$3]++} END {for (k in c) printf "  %s bit: %d\n", k, c[k]}' "$rows" | LC_ALL=C sort
    echo
    echo "=== channels ==="
    awk -F'\t' '{c[$4]++} END {for (k in c) printf "  %s ch: %d\n", k, c[k]}' "$rows" | LC_ALL=C sort
    echo
    echo "=== totals ==="
    awk -F'\t' '
      {
        bytes += $5
        dur += $6
        if ($7 == 1) rg++
        if ($8 == 1) art++
        if ($9 == 1) ok++
      }
      END {
        printf "  bytes: %d (%.2f GiB)\n", bytes, bytes/1024/1024/1024
        printf "  duration: %.1f hours\n", dur/3600
        printf "  with ReplayGain: %d\n", rg+0
        printf "  with picture: %d\n", art+0
        printf "  flac -t ok: %d / %d\n", ok+0, NR
      }
    ' "$rows"
  } >"$report"
  chmod 600 -- "$report" 2>/dev/null || true
  log_always "Inventory report: $report"
  cat -- "$report"
}
