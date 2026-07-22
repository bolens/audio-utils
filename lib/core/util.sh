#!/usr/bin/env bash
# Misc shared helpers: deps, jobs, library roots.

# Default parallel jobs: max(1, cpu_count/2)
default_jobs() {
  local n
  n=$(au_cpu_count)
  if ((n < 2)); then
    echo 1
  else
    echo $((n / 2))
  fi
}

require_cmds() {
  local missing=()
  local c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      missing+=("$c")
    fi
  done
  if ((${#missing[@]})); then
    log_err "Error: missing required command(s): ${missing[*]}"
    return 1
  fi
}

# Populate array name passed as $1 from AUDIO_UTILS_ROOTS / WAV2FLAC_ROOTS.
# Returns 0 if at least one root was set.
audio_utils_roots_from_env() {
  local -n _out=$1
  local raw="${AUDIO_UTILS_ROOTS:-${WAV2FLAC_ROOTS:-}}"
  _out=()
  [[ -n "$raw" ]] || return 1
  # shellcheck disable=SC2206
  _out=($raw)
  ((${#_out[@]} > 0))
}

# Resolve roots from "$@" or AUDIO_UTILS_ROOTS; print error and return 2 if empty.
# Usage: audio_utils_resolve_roots ROOTS_ARRAY_NAME "$@"
audio_utils_resolve_roots() {
  local -n _roots=$1
  shift
  _roots=("$@")
  if ((${#_roots[@]} == 0)); then
    audio_utils_roots_from_env _roots || {
      echo "Error: pass roots or set AUDIO_UTILS_ROOTS" >&2
      return 2
    }
  fi
  return 0
}

# Meta flags for simple find-* scripts (roots only; no --ext).
# Exits 0 on -h/--help/--version; exits 2 on unknown -*.
# Usage: audio_utils_find_simple_meta NAME "one-line description" "$@"
audio_utils_find_simple_meta() {
  local name=$1 desc=$2 a
  shift 2
  for a in "$@"; do
    case "$a" in
      -h|--help)
        printf 'Usage: %s [ROOT ...]\n' "$name"
        printf '%s\n' "$desc"
        printf 'Roots: args, else AUDIO_UTILS_ROOTS / config.\n'
        exit 0
        ;;
      --version)
        audio_utils_print_version "$name"
        exit 0
        ;;
      -*)
        echo "Error: unknown option: $a (pass roots only; try -h)" >&2
        exit 2
        ;;
    esac
  done
}

# List directories named NAME (case-insensitive) under roots.
# Usage: find_named_dirs NAME ROOT [ROOT ...]
find_named_dirs() {
  local name=$1
  shift
  [[ -n "$name" && $# -gt 0 ]] || return 2
  LC_ALL=C find -P "$@" -type d -iname "$name" 2>/dev/null | LC_ALL=C sort -u
}
