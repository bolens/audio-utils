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

# Read a NUL-delimited stream into the array named by $1 (Bash 4.3-compatible).
au_mapfile0() {
  # shellcheck disable=SC2178 # nameref target is explicitly an array name
  local -n _out=$1
  local input="${2:-}" item
  _out=()
  if [[ -n "$input" ]]; then
    while IFS= read -r -d '' item; do
      _out+=("$item")
    done <"$input"
    return
  fi
  while IFS= read -r -d '' item; do
    _out+=("$item")
  done
}

# Populate array name passed as $1 from AUDIO_UTILS_ROOTS_FILE, or the legacy
# space-separated AUDIO_UTILS_ROOTS / WAV2FLAC_ROOTS values.
# Returns 0 if at least one root was set.
audio_utils_roots_from_env() {
  # shellcheck disable=SC2178 # nameref target is explicitly an array name
  local -n _out=$1
  local raw="${AUDIO_UTILS_ROOTS:-${WAV2FLAC_ROOTS:-}}"
  local roots_file="${AUDIO_UTILS_ROOTS_FILE:-}"
  local line
  _out=()
  if [[ -n "$roots_file" ]]; then
    [[ -f "$roots_file" ]] || {
      echo "Error: AUDIO_UTILS_ROOTS_FILE not found: $roots_file" >&2
      return 1
    }
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ -n "$line" ]] && _out+=("$line")
    done <"$roots_file"
    ((${#_out[@]} > 0))
    return
  fi
  [[ -n "$raw" ]] || return 1
  # shellcheck disable=SC2206
  _out=($raw)
  ((${#_out[@]} > 0))
}

# Resolve roots from "$@", AUDIO_UTILS_ROOTS_FILE, or AUDIO_UTILS_ROOTS.
# Usage: audio_utils_resolve_roots ROOTS_ARRAY_NAME "$@"
audio_utils_resolve_roots() {
  local -n _roots=$1
  shift
  _roots=("$@")
  if ((${#_roots[@]} == 0)); then
    audio_utils_roots_from_env _roots || {
      echo "Error: pass roots or set AUDIO_UTILS_ROOTS_FILE / AUDIO_UTILS_ROOTS" >&2
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

# Parse options and resolve roots for simple find-* scripts.
# Usage: audio_utils_parse_simple_find PRINT0_VAR ROOTS_VAR NAME DESC "$@"
audio_utils_parse_simple_find() {
  local print0_name=$1 roots_name=$2
  local -n _print0=$print0_name
  # shellcheck disable=SC2178 # nameref target is explicitly an array name
  local -n _roots=$roots_name
  local name=$3 desc=$4
  shift 4
  _print0=0
  _roots=()
  while (($# > 0)); do
    case "$1" in
      --print0)
        _print0=1
        shift
        ;;
      -h|--help)
        printf 'Usage: %s [--print0] [ROOT ...]\n' "$name"
        printf '%s\n' "$desc"
        printf '%s\n' '  --print0  NUL-delimit output (safe for all filenames)'
        printf 'Roots: args, else AUDIO_UTILS_ROOTS / config.\n'
        exit 0
        ;;
      --version)
        audio_utils_print_version "$name"
        exit 0
        ;;
      --)
        shift
        _roots+=("$@")
        break
        ;;
      -*)
        echo "Error: unknown option: $1 (try -h)" >&2
        exit 2
        ;;
      *)
        _roots+=("$1")
        shift
        ;;
    esac
  done
  audio_utils_resolve_roots "$roots_name" "${_roots[@]}"
}

# List directories named NAME (case-insensitive) under roots.
# Usage: find_named_dirs [--print0] NAME ROOT [ROOT ...]
find_named_dirs() {
  local print0=0
  if [[ ${1:-} == --print0 ]]; then
    print0=1
    shift
  fi
  local name=${1:-}
  shift
  [[ -n "$name" && $# -gt 0 ]] || return 2
  local root
  local -a roots=()
  for root in "$@"; do
    if [[ $root == -* ]]; then
      roots+=("./$root")
    else
      roots+=("$root")
    fi
  done
  if ((print0)); then
    LC_ALL=C find -P "${roots[@]}" -type d -iname "$name" -print0 2>/dev/null |
      LC_ALL=C sort -zu
  else
    LC_ALL=C find -P "${roots[@]}" -type d -iname "$name" 2>/dev/null |
      LC_ALL=C sort -u
  fi
}
