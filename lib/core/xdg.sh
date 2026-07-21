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

# Preferred state path WITHOUT creating directories (lazy).
audio_utils_state_dir_path() {
  local tool="${1:-}"
  local suffix=""
  [[ -n "$tool" ]] && suffix="/${tool}"
  printf '%s\n' "$(audio_utils_xdg_state_home)/audio-utils${suffix}"
}

# Persistent per-user state (logs, run history). Optional tool subdirectory.
# Prints path; creates directory. Falls back to cache/runtime/tmp if needed.
audio_utils_state_dir() {
  local tool="${1:-}"
  local suffix="" cand
  [[ -n "$tool" ]] && suffix="/${tool}"

  cand=$(_audio_utils_first_writable_dir "" \
    "$(audio_utils_xdg_state_home)/audio-utils${suffix}" \
    "$(audio_utils_xdg_cache_home)/audio-utils/state${suffix}" \
    "${TMPDIR:-/tmp}/audio-utils-state${suffix}") || return 1
  printf '%s\n' "$cand"
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
  local tool="${1:-}"
  local suffix="" cand
  [[ -n "$tool" ]] && suffix="/${tool}"

  cand=$(_audio_utils_first_writable_dir "" \
    "$(audio_utils_xdg_cache_home)/audio-utils${suffix}" \
    "${TMPDIR:-/tmp}/audio-utils-cache${suffix}") || return 1
  printf '%s\n' "$cand"
}

# Short-lived runtime base (status files, mktemp, registry).
# Prefer XDG_RUNTIME_DIR; fall back to cache/runtime then TMPDIR.
audio_utils_runtime_dir() {
  local cand
  cand=$(_audio_utils_first_writable_dir 700 \
    "${XDG_RUNTIME_DIR:+${XDG_RUNTIME_DIR}/audio-utils}" \
    "$(audio_utils_xdg_cache_home)/audio-utils/runtime" \
    "${TMPDIR:-/tmp}/audio-utils-runtime-$$") || return 1
  printf '%s\n' "$cand"
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
