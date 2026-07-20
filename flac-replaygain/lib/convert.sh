#!/usr/bin/env bash
# Apply ReplayGain to one FLAC (album: once per directory; track: per file).

_rg_dir_key() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

_rg_has_track_gain() {
  local v
  v=$(metaflac --show-tag=REPLAYGAIN_TRACK_GAIN -- "$1" 2>/dev/null | head -n1)
  [[ -n "$v" ]]
}

_rg_list_flacs() {
  local dir=$1
  LC_ALL=C find -P "$dir" -maxdepth 1 -type f -iname '*.flac' | LC_ALL=C sort
}

_rg_run_rsgain() {
  local -a files=("$@")
  local -a args=(custom -s i -q)
  if [[ "${RG_TRACK_ONLY:-0}" -eq 0 ]]; then
    args+=(-a)
  fi
  if [[ "${OVERWRITE:-0}" -eq 0 ]]; then
    args+=(-S)
  fi
  rsgain "${args[@]}" -- "${files[@]}"
}

_rg_run_loudgain() {
  local -a files=("$@")
  local -a args=(-s e -k -q)
  if [[ "${RG_TRACK_ONLY:-0}" -eq 0 ]]; then
    args+=(-a)
  fi
  loudgain "${args[@]}" -- "${files[@]}"
}

_rg_apply() {
  local -a files=("$@")
  case "${RG_BACKEND}" in
    rsgain) _rg_run_rsgain "${files[@]}" ;;
    loudgain) _rg_run_loudgain "${files[@]}" ;;
    *)
      log_err "unknown RG backend: ${RG_BACKEND:-}"
      return 1
      ;;
  esac
}

_rg_album_locked() {
  local dir=$1
  local done_f=$2
  local -a flacs=()
  local all_have=1 f

  if [[ -f "$done_f" ]]; then
    return 0
  fi

  mapfile -t flacs < <(_rg_list_flacs "$dir")
  if ((${#flacs[@]} == 0)); then
    printf 'empty\n' >"$done_f"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry\n' >"$done_f"
    return 0
  fi

  if [[ "${OVERWRITE:-0}" -eq 0 && "${RG_BACKEND}" == loudgain ]]; then
    for f in "${flacs[@]}"; do
      if ! _rg_has_track_gain "$f"; then
        all_have=0
        break
      fi
    done
    if [[ "$all_have" -eq 1 ]]; then
      printf 'skipped\n' >"$done_f"
      return 0
    fi
  fi

  if ! _rg_apply "${flacs[@]}"; then
    printf 'fail\n' >"$done_f"
    return 1
  fi
  printf 'ok\n' >"$done_f"
  return 0
}

convert_one() {
  local flac="$1"
  local dir key lock done_f mode sha state rg_rc=0

  dir=$(dirname -- "$flac")
  mode="album"
  [[ "${RG_TRACK_ONLY:-0}" -eq 1 ]] && mode="track"

  if [[ "${RG_TRACK_ONLY:-0}" -eq 1 ]]; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      log_progress "would rg-track: $flac"
      return 0
    fi
    if [[ "${OVERWRITE:-0}" -eq 0 ]] && _rg_has_track_gain "$flac"; then
      log_progress "skip (rg exists): $flac"
      log_success "$flac" "$mode" "" "$(file_sha256 "$flac")" "skipped-existing"
      return 0
    fi
    if ! _rg_apply "$flac"; then
      log_fail "$flac" "replaygain failed" "backend=$RG_BACKEND mode=$mode"
      return 1
    fi
    sha=$(file_sha256 "$flac")
    log_progress "rg-track: $flac"
    log_success "$flac" "$mode" "" "$sha" "ok"
    return 0
  fi

  key=$(_rg_dir_key "$dir")
  lock="${AU_RG_STATE_DIR:?}/$key.lock"
  done_f="${AU_RG_STATE_DIR}/$key.done"

  (
    flock 9
    _rg_album_locked "$dir" "$done_f"
  ) 9>"$lock" || rg_rc=$?

  if [[ "$rg_rc" -ne 0 ]]; then
    log_fail "$flac" "album replaygain failed" "dir=$dir backend=$RG_BACKEND"
    return 1
  fi

  state=$(cat -- "$done_f" 2>/dev/null || true)
  case "$state" in
    dry)
      log_progress "would rg-album: $dir"
      return 0
      ;;
    skipped)
      log_progress "skip (rg exists): $flac"
      log_success "$flac" "$mode" "" "$(file_sha256 "$flac")" "skipped-existing-album"
      return 0
      ;;
    empty)
      log_progress "skip (no flacs): $dir"
      return 0
      ;;
    ok)
      sha=$(file_sha256 "$flac")
      log_progress "rg-album: $flac"
      log_success "$flac" "$mode" "" "$sha" "ok"
      return 0
      ;;
    fail)
      log_fail "$flac" "album replaygain failed" "dir=$dir"
      return 1
      ;;
    *)
      log_fail "$flac" "album replaygain unknown state" "dir=$dir state=$state"
      return 1
      ;;
  esac
}
