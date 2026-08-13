#!/usr/bin/env bash
# Temp workdir registry + EXIT/INT cleanup.
#
# Env:
#   AUDIO_UTILS_WORKDIR_PREFIX  — mktemp name fragment (default: audio-utils)
#                                 workdirs: .${prefix}.XXXXXX beside dest
#
# Registry / fallback temps use XDG runtime (see xdg.sh).
# Album-side workdirs stay next to the destination for same-FS atomic mv.

init_tmpdir_registry() {
  AUDIO_UTILS_TMP_REGISTRY=$(audio_utils_mktemp_d "registry.XXXXXX")
  export AUDIO_UTILS_TMP_REGISTRY
}

register_tmpdir() {
  local dir="$1" id
  [[ -n "${AUDIO_UTILS_TMP_REGISTRY:-}" && -d "${AUDIO_UTILS_TMP_REGISTRY}" ]] || return 0
  id=$(au_sha256_str "$dir")
  printf '%s\n' "$dir" >"${AUDIO_UTILS_TMP_REGISTRY}/${id}"
}

unregister_tmpdir() {
  local dir="$1" id
  [[ -n "${AUDIO_UTILS_TMP_REGISTRY:-}" && -d "${AUDIO_UTILS_TMP_REGISTRY}" ]] || return 0
  id=$(au_sha256_str "$dir")
  rm -f -- "${AUDIO_UTILS_TMP_REGISTRY}/${id}"
}

_audio_utils_registered_tmpdir_safe() {
  local dir=$1 abs runtime base
  [[ -n "$dir" && -d "$dir" && ! -L "$dir" ]] || return 1
  abs=$(au_abspath "$dir") || return 1
  [[ -n "$abs" && "$abs" != / ]] || return 1
  runtime=$(audio_utils_runtime_dir) || return 1
  runtime=$(au_abspath "$runtime") || return 1
  case "$abs" in
    "$runtime"/*) return 0 ;;
  esac
  base=$(basename -- "$abs")
  [[ "$base" =~ ^\.[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9]{6}$ ]]
}

cleanup_registered_tmpdirs() {
  local f d fail=0
  [[ -n "${AUDIO_UTILS_TMP_REGISTRY:-}" && -d "${AUDIO_UTILS_TMP_REGISTRY}" ]] || return 0
  for f in "${AUDIO_UTILS_TMP_REGISTRY}"/*; do
    [[ -f "$f" ]] || continue
    d=$(<"$f")
    if [[ -e "$d" ]] && ! _audio_utils_registered_tmpdir_safe "$d"; then
      log_err "refusing unsafe registered temporary directory: $d"
      fail=1
    elif [[ -n "$d" ]]; then
      rm -rf -- "$d"
    fi
    rm -f -- "$f"
  done
  rmdir -- "${AUDIO_UTILS_TMP_REGISTRY}" 2>/dev/null || rm -rf -- "${AUDIO_UTILS_TMP_REGISTRY}"
  return "$fail"
}

install_cleanup_trap() {
  trap 'cleanup_registered_tmpdirs' EXIT INT TERM HUP
}

audio_utils_workdir_prefix() {
  local prefix="${AUDIO_UTILS_WORKDIR_PREFIX:-audio-utils}"
  if [[ ! "$prefix" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    log_err "invalid AUDIO_UTILS_WORKDIR_PREFIX: $prefix"
    return 2
  fi
  printf '%s\n' "$prefix"
}

_audio_utils_workdir_name_safe() {
  local name=$1 prefix=$2 suffix
  [[ "$name" == ".${prefix}."* ]] || return 1
  suffix=${name#".${prefix}."}
  [[ "$suffix" =~ ^[A-Za-z0-9]{6}$ ]]
}

# Prefer temp dir on same filesystem as dest for atomic mv.
# Uses AUDIO_UTILS_WORKDIR_PREFIX (default audio-utils).
# Fallback: XDG runtime dir (not a random world-writable /tmp root alone).
make_workdir() {
  local dest_dir="$1"
  local prefix tmp
  prefix=$(audio_utils_workdir_prefix) || return
  if tmp=$(mktemp -d "${dest_dir}/.${prefix}.XXXXXX" 2>/dev/null); then
    register_tmpdir "$tmp"
    printf '%s\n' "$tmp"
    return 0
  fi
  tmp=$(audio_utils_mktemp_d "${prefix}.XXXXXX")
  register_tmpdir "$tmp"
  printf '%s\n' "$tmp"
}

# Remove leftover .${prefix}.XXXXXX workdirs under DIR (maxdepth 1).
sweep_orphan_workdirs() {
  local dir="$1"
  local prefix d count=0
  prefix=$(audio_utils_workdir_prefix) || return
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' d; do
    _audio_utils_workdir_name_safe "$(basename -- "$d")" "$prefix" || continue
    rm -rf -- "$d" 2>/dev/null || chmod -R u+w -- "$d" 2>/dev/null
    rm -rf -- "$d" 2>/dev/null || true
    ((count++)) || true
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d \
    -name ".${prefix}.*" -print0 2>/dev/null)
  if ((count > 0)); then
    log_info "swept $count orphan workdir(s) under $dir"
  fi
}

# Recursively remove orphan .${prefix}.XXXXXX workdirs under roots.
sweep_orphans_in_roots() {
  local prefix root d count=0
  prefix=$(audio_utils_workdir_prefix) || return
  for root in "$@"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' d; do
      _audio_utils_workdir_name_safe "$(basename -- "$d")" "$prefix" || continue
      rm -rf -- "$d" 2>/dev/null || chmod -R u+w -- "$d" 2>/dev/null
      rm -rf -- "$d" 2>/dev/null || true
      ((count++)) || true
    done < <(find "$root" -mindepth 1 -type d \
      -name ".${prefix}.*" -print0 2>/dev/null)
  done
  if ((count > 0)); then
    log_info "swept $count orphan .${prefix}.XXXXXX workdir(s)"
  fi
}
