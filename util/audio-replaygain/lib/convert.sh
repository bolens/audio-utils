#!/usr/bin/env bash
# Apply ReplayGain to one audio file (album once per dir; track per file).

_rg_dir_key() { printf '%s' "$1" | sha256sum | awk '{print $1}'; }

_rg_has_track_gain() {
  local v
  v=$(audio_meta_get "$1" REPLAYGAIN_TRACK_GAIN)
  [[ -n "$v" ]] && return 0
  v=$(audio_meta_get "$1" replaygain_track_gain)
  [[ -n "$v" ]]
}

_rg_list_audio() {
  local dir=$1 ext
  local -a find_args=( -P "$dir" -maxdepth 1 -type f \( )
  local first=1
  for ext in flac mp3 opus m4a ogg oga wma mpc aac; do
    if [[ "$first" -eq 1 ]]; then
      find_args+=( -iname "*.${ext}" ); first=0
    else
      find_args+=( -o -iname "*.${ext}" )
    fi
  done
  find_args+=( \) )
  LC_ALL=C find "${find_args[@]}" | LC_ALL=C sort
}

_rg_run_rsgain() {
  local -a args=(custom -s i -q)
  [[ "${RG_TRACK_ONLY:-0}" -eq 0 ]] && args+=(-a)
  [[ "${OVERWRITE:-0}" -eq 0 ]] && args+=(-S)
  rsgain "${args[@]}" -- "$@"
}

_rg_run_loudgain() {
  local -a args=(-s e -k -q)
  [[ "${RG_TRACK_ONLY:-0}" -eq 0 ]] && args+=(-a)
  loudgain "${args[@]}" -- "$@"
}

_rg_apply() {
  case "${RG_BACKEND}" in
    rsgain) _rg_run_rsgain "$@" ;;
    loudgain) _rg_run_loudgain "$@" ;;
    *) log_err "unknown RG backend: ${RG_BACKEND:-}"; return 1 ;;
  esac
}

_rg_album_locked() {
  local dir=$1 done_f=$2
  local -a files=()
  local all_have=1 f

  [[ -f "$done_f" ]] && return 0
  mapfile -t files < <(_rg_list_audio "$dir")
  if ((${#files[@]} == 0)); then
    printf 'empty\n' >"$done_f"; return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry\n' >"$done_f"; return 0
  fi
  if [[ "${OVERWRITE:-0}" -eq 0 && "${RG_BACKEND}" == loudgain ]]; then
    for f in "${files[@]}"; do
      if ! _rg_has_track_gain "$f"; then all_have=0; break; fi
    done
    if [[ "$all_have" -eq 1 ]]; then
      printf 'skipped\n' >"$done_f"; return 0
    fi
  fi
  if ! _rg_apply "${files[@]}"; then
    printf 'fail\n' >"$done_f"; return 1
  fi
  printf 'ok\n' >"$done_f"
}

convert_one() {
  local src="$1" dir key lock done_f mode state rg_rc=0
  dir=$(dirname -- "$src")
  mode="album"
  [[ "${RG_TRACK_ONLY:-0}" -eq 1 ]] && mode="track"

  if [[ "${RG_TRACK_ONLY:-0}" -eq 1 ]]; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      log_progress "would rg-track: $src"; return 0
    fi
    if [[ "${OVERWRITE:-0}" -eq 0 ]] && _rg_has_track_gain "$src"; then
      log_progress "skip (rg exists): $src"
      log_success "$src" "$mode" "" "$(file_sha256 "$src")" "skipped-existing"
      return 0
    fi
    if ! _rg_apply "$src"; then
      log_fail "$src" "replaygain failed" "backend=$RG_BACKEND"
      return 1
    fi
    log_progress "rg-track: $src"
    log_success "$src" "$mode" "" "$(file_sha256 "$src")" "ok"
    return 0
  fi

  key=$(_rg_dir_key "$dir")
  lock="${AU_RG_STATE_DIR:?}/$key.lock"
  done_f="${AU_RG_STATE_DIR}/$key.done"
  ( flock 9; _rg_album_locked "$dir" "$done_f" ) 9>"$lock" || rg_rc=$?
  if [[ "$rg_rc" -ne 0 ]]; then
    log_fail "$src" "album replaygain failed" "dir=$dir"; return 1
  fi
  state=$(cat -- "$done_f" 2>/dev/null || true)
  case "$state" in
    dry) log_progress "would rg-album: $dir"; return 0 ;;
    skipped)
      log_progress "skip (rg exists): $src"
      log_success "$src" "$mode" "" "$(file_sha256 "$src")" "skipped-existing-album"
      return 0 ;;
    empty) log_progress "skip (no audio): $dir"; return 0 ;;
    ok)
      log_progress "rg-album: $src"
      log_success "$src" "$mode" "" "$(file_sha256 "$src")" "ok"
      return 0 ;;
    fail) log_fail "$src" "album replaygain failed" "dir=$dir"; return 1 ;;
    *) log_fail "$src" "album replaygain unknown state" "state=$state"; return 1 ;;
  esac
}
