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

cleanup_registered_tmpdirs() {
  local f d
  [[ -n "${AUDIO_UTILS_TMP_REGISTRY:-}" && -d "${AUDIO_UTILS_TMP_REGISTRY}" ]] || return 0
  for f in "${AUDIO_UTILS_TMP_REGISTRY}"/*; do
    [[ -f "$f" ]] || continue
    d=$(<"$f")
    [[ -n "$d" ]] && rm -rf -- "$d"
    rm -f -- "$f"
  done
  rmdir -- "${AUDIO_UTILS_TMP_REGISTRY}" 2>/dev/null || rm -rf -- "${AUDIO_UTILS_TMP_REGISTRY}"
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

# Remove leftover .${prefix}.* workdirs under DIR (maxdepth 1).
sweep_orphan_workdirs() {
  local dir="$1"
  local prefix d count=0
  prefix=$(audio_utils_workdir_prefix) || return
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' d; do
    rm -rf -- "$d" 2>/dev/null || chmod -R u+w -- "$d" 2>/dev/null
    rm -rf -- "$d" 2>/dev/null || true
    ((count++)) || true
  done < <(find "$dir" -maxdepth 1 -type d -name ".${prefix}.*" -print0 2>/dev/null)
  if ((count > 0)); then
    log_info "swept $count orphan workdir(s) under $dir"
  fi
}

# Recursively remove orphan .${prefix}.* under roots.
sweep_orphans_in_roots() {
  local prefix root d count=0
  prefix=$(audio_utils_workdir_prefix) || return
  for root in "$@"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' d; do
      rm -rf -- "$d" 2>/dev/null || chmod -R u+w -- "$d" 2>/dev/null
      rm -rf -- "$d" 2>/dev/null || true
      ((count++)) || true
    done < <(find "$root" -type d -name ".${prefix}.*" -print0 2>/dev/null)
  done
  if ((count > 0)); then
    log_info "swept $count orphan .${prefix}.* workdir(s)"
  fi
}
