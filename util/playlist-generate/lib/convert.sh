#!/usr/bin/env bash
# Once per directory: write <dirname>.m3u beside tracks (relative paths, path-deduped).

_plgen_dir_key() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

_plgen_build_dir() {
  local dir=$1
  local done_f=$2
  local out entries n base
  local -a audio=()

  if [[ -f "$done_f" ]]; then
    return 0
  fi

  base=$(basename -- "$dir")
  out="${dir}/${base}.m3u"

  mapfile -t audio < <(playlist_list_audio_in_dir "$dir")
  n=${#audio[@]}
  if ((n == 0)); then
    printf 'empty\n' >"$done_f"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry\n' >"$done_f"
    return 0
  fi

  if [[ -f "$out" && "${OVERWRITE:-0}" -eq 0 ]]; then
    printf 'exists\n' >"$done_f"
    return 0
  fi

  entries=$(audio_utils_mktemp "plgen.XXXXXX") || {
    printf 'fail\n' >"$done_f"
    return 1
  }
  playlist_entries_from_dir "$dir" >"$entries"
  if [[ ! -s "$entries" ]]; then
    printf 'empty\n' >"$done_f"
    return 0
  fi

  if ! playlist_write m3u "$out" "$dir" relative <"$entries"; then
    printf 'fail\n' >"$done_f"
    return 1
  fi

  printf 'ok\n' >"$done_f"
  return 0
}

convert_one() {
  local src="$1" dir key lock done_f state

  dir=$(cd -- "$(dirname -- "$src")" && pwd) || {
    log_fail "$src" "cannot resolve directory"
    return 1
  }

  key=$(_plgen_dir_key "$dir")
  lock="${AU_PLGEN_STATE:?}/$key.lock"
  done_f="${AU_PLGEN_STATE}/$key.done"

  (
    flock 9
    _plgen_build_dir "$dir" "$done_f"
  ) 9>"$lock"
  state=$(cat "$done_f" 2>/dev/null || echo fail)

  case "$state" in
    dry)
      log_progress "would generate: ${dir}/$(basename -- "$dir").m3u"
      log_success "$src" "dry" "" "" "dir"
      ;;
    exists)
      log_progress "skip (exists): ${dir}/$(basename -- "$dir").m3u"
      log_success "$src" "skip" "" "" "exists"
      ;;
    empty)
      log_progress "skip (no audio): $dir"
      log_success "$src" "skip" "" "" "empty"
      ;;
    ok)
      log_progress "generated: ${dir}/$(basename -- "$dir").m3u"
      log_success "$src" "generated" "" "$(file_sha256 "${dir}/$(basename -- "$dir").m3u")" "m3u"
      ;;
    *)
      log_fail "$src" "playlist generate failed" "dir=$dir"
      return 1
      ;;
  esac
  return 0
}
