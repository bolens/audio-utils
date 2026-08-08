#!/usr/bin/env bash
# XDG Base Directory helpers (cross-distro user paths).
#
#   State  → ${XDG_STATE_HOME:-$HOME/.local/state}/audio-utils[/TOOL]
#   Cache  → ${XDG_CACHE_HOME:-$HOME/.cache}/audio-utils
#   Runtime temps → $XDG_RUNTIME_DIR/audio-utils  (else cache/runtime)
#
# Album-side workdirs (make_workdir) stay beside the destination for atomic mv;
# only the fallback path uses the runtime base.

audio_utils_xdg_state_home() {
  if [[ -n "${XDG_STATE_HOME:-}" ]]; then
    printf '%s\n' "$XDG_STATE_HOME"
  elif [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.local/state"
  else
    printf '%s\n' "${TMPDIR:-/tmp}"
  fi
}

audio_utils_xdg_cache_home() {
  if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
    printf '%s\n' "$XDG_CACHE_HOME"
  elif [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.cache"
  else
    printf '%s\n' "${TMPDIR:-/tmp}"
  fi
}

# Ensure dir exists and is writable. Optional mode applied to the leaf via chmod
# (mkdir -p -m only sets the deepest component; parents may already exist).
_audio_utils_ensure_dir() {
  local dir="$1" mode="${2:-}"
  mkdir -p -- "$dir" || return 1
  if [[ -n "$mode" ]]; then
    chmod "$mode" -- "$dir" 2>/dev/null || true
  fi
  [[ -d "$dir" && -w "$dir" ]]
}

# Ensure a runtime dir is owned by this user and cannot be a symlink. Runtime
# files may contain command arguments and status, so a merely writable path is
# not sufficient when falling back to a shared temporary parent.
_audio_utils_ensure_private_dir() {
  local dir="$1" owner
  [[ ! -L "$dir" ]] || return 1
  mkdir -p -- "$dir" || return 1
  [[ -d "$dir" && ! -L "$dir" ]] || return 1
  owner=$(stat -c %u -- "$dir") || return 1
  [[ "$owner" -eq "$EUID" ]] || return 1
  chmod 700 -- "$dir" || return 1
  [[ -w "$dir" ]]
}

# Try candidates in order; print first writable path. Args: mode(or empty) dirs...
_audio_utils_first_writable_dir() {
  local mode="$1"
  shift
  local d
  for d in "$@"; do
    [[ -n "$d" ]] || continue
    if _audio_utils_ensure_dir "$d" "$mode"; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

_audio_utils_namespace_suffix() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    return 0
  fi
  if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "Error: invalid audio-utils namespace: $name" >&2
    return 2
  fi
  printf '/%s' "$name"
}

_audio_utils_private_fallback_path() {
  local kind="$1" suffix="$2"
  printf '%s/audio-utils-%s/%s%s\n' "${TMPDIR:-/tmp}" "$EUID" "$kind" "$suffix"
}

_audio_utils_private_fallback_dir() {
  local kind="$1" suffix="$2" root dir
  root="${TMPDIR:-/tmp}/audio-utils-${EUID}"
  dir=$(_audio_utils_private_fallback_path "$kind" "$suffix") || return 1
  _audio_utils_ensure_private_dir "$root" || return 1
  _audio_utils_ensure_private_dir "$dir" || return 1
  printf '%s\n' "$dir"
}

# Preferred state path WITHOUT creating directories (lazy).
audio_utils_state_dir_path() {
  local tool="${1:-}"
  local suffix
  suffix=$(_audio_utils_namespace_suffix "$tool") || return
  if [[ -n "${XDG_STATE_HOME:-}" || -n "${HOME:-}" ]]; then
    printf '%s\n' "$(audio_utils_xdg_state_home)/audio-utils${suffix}"
  else
    _audio_utils_private_fallback_path state "$suffix"
  fi
}

# Persistent per-user state (logs, run history). Optional tool subdirectory.
# Prints path; creates directory. Falls back to cache/runtime/tmp if needed.
audio_utils_state_dir() {
  local tool="${1:-}" suffix cand
  local -a candidates=()
  suffix=$(_audio_utils_namespace_suffix "$tool") || return

  if [[ -n "${XDG_STATE_HOME:-}" || -n "${HOME:-}" ]]; then
    candidates+=("$(audio_utils_xdg_state_home)/audio-utils${suffix}")
  fi
  if [[ -n "${XDG_CACHE_HOME:-}" || -n "${HOME:-}" ]]; then
    candidates+=("$(audio_utils_xdg_cache_home)/audio-utils/state${suffix}")
  fi
  if ((${#candidates[@]})); then
    cand=$(_audio_utils_first_writable_dir "" "${candidates[@]}") && {
      printf '%s\n' "$cand"
      return 0
    }
  fi
  _audio_utils_private_fallback_dir state "$suffix"
}

# Ensure parent dir exists; optionally truncate; chmod 600.
# mode_create: "truncate" → create/empty file; otherwise create if missing.
audio_utils_ensure_log_file() {
  local file="$1"
  local mode_create="${2:-}"
  local dir
  dir=$(dirname -- "$file")
  mkdir -p -- "$dir" || return 1
  if [[ "$mode_create" == "truncate" ]]; then
    : >"$file" || return 1
  elif [[ ! -e "$file" ]]; then
    : >"$file" || return 1
  fi
  chmod 600 -- "$file" 2>/dev/null || true
}

# Cache root for non-essential data.
audio_utils_cache_dir() {
  local tool="${1:-}" suffix cand
  suffix=$(_audio_utils_namespace_suffix "$tool") || return

  if [[ -n "${XDG_CACHE_HOME:-}" || -n "${HOME:-}" ]]; then
    cand=$(_audio_utils_first_writable_dir "" \
      "$(audio_utils_xdg_cache_home)/audio-utils${suffix}") && {
        printf '%s\n' "$cand"
        return 0
      }
  fi
  _audio_utils_private_fallback_dir cache "$suffix"
}

# Short-lived runtime base (status files, mktemp, registry).
# Prefer XDG_RUNTIME_DIR; fall back to cache/runtime then TMPDIR.
audio_utils_runtime_dir() {
  local cand
  for cand in \
    "${XDG_RUNTIME_DIR:+${XDG_RUNTIME_DIR}/audio-utils}" \
    "$(audio_utils_xdg_cache_home)/audio-utils/runtime" \
    "${TMPDIR:-/tmp}/audio-utils-runtime-${EUID}"; do
    [[ -n "$cand" ]] || continue
    if _audio_utils_ensure_private_dir "$cand"; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

# mktemp file under runtime dir. Optional name template (default: tmp.XXXXXX).
audio_utils_mktemp() {
  local template="${1:-tmp.XXXXXX}"
  local base
  base=$(audio_utils_runtime_dir) || return 1
  mktemp -- "${base}/${template}"
}

# mktemp -d under runtime dir. Optional name template (default: tmp.XXXXXX).
audio_utils_mktemp_d() {
  local template="${1:-tmp.XXXXXX}"
  local base
  base=$(audio_utils_runtime_dir) || return 1
  mktemp -d -- "${base}/${template}"
}
