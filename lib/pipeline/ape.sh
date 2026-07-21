#!/usr/bin/env bash
# Monkey's Audio (mac encoder) resolution and wrappers.
#
# No distro packages the encoder; scripts/ape-codec.sh builds and installs it
# to ~/.local/bin following XDG conventions. Resolution order:
#   1. AUDIO_UTILS_MAC (explicit path or command name)
#   2. mac on PATH
#   3. ~/.local/bin/mac (the ape-codec.sh install target, for non-login PATHs)

# Validate compression level: named profile or numeric 1000–5000 step 1000.
ape_level_ok() {
  local l="${1,,}"
  [[ "$l" =~ ^(fast|normal|high|extrahigh|insane|[1-5]000)$ ]]
}

# Named profile → mac -c level (numbers pass through).
ape_level_num() {
  case "${1,,}" in
    fast) printf 1000 ;;
    normal) printf 2000 ;;
    high) printf 3000 ;;
    extrahigh) printf 4000 ;;
    insane) printf 5000 ;;
    *) printf '%s' "$1" ;;
  esac
}

# Populate MAC_CMD array with the mac binary to use.
mac_resolve() {
  MAC_CMD=()

  if [[ -n "${AUDIO_UTILS_MAC:-}" ]]; then
    local bin=$AUDIO_UTILS_MAC
    if [[ ! -x "$bin" && ! -x "$(command -v "$bin" 2>/dev/null || true)" ]]; then
      log_err "Error: AUDIO_UTILS_MAC not found or not executable: $bin"
      return 1
    fi
    MAC_CMD=("$bin")
    : "${MAC_CMD[@]}"
    return 0
  fi

  if command -v mac >/dev/null 2>&1; then
    MAC_CMD=(mac)
    : "${MAC_CMD[@]}"
    return 0
  fi
  if [[ -x "${HOME}/.local/bin/mac" ]]; then
    MAC_CMD=("${HOME}/.local/bin/mac")
    : "${MAC_CMD[@]}"
    return 0
  fi

  log_err "Error: mac (Monkey's Audio) not found"
  log_err "  Install it with: scripts/ape-codec.sh install"
  log_err "  or set AUDIO_UTILS_MAC to the binary"
  return 1
}

# Encode WAV → DEST (.ape) at LEVEL (profile name or 1000–5000).
mac_encode() {
  local wav="$1" dest="$2" level="${3:-normal}"
  local err num

  if ! ape_level_ok "$level"; then
    log_err "Error: invalid APE level '$level' (fast|normal|high|extrahigh|insane or 1000-5000)"
    return 1
  fi
  num=$(ape_level_num "$level")
  if ((${#MAC_CMD[@]} == 0)); then
    mac_resolve || return 1
  fi

  err="$(dirname -- "$dest")/mac-encode.err"
  if ! "${MAC_CMD[@]}" "$wav" "$dest" "-c$num" >/dev/null 2>"$err"; then
    set_last_err_file "$err"
    log_err "FAILED mac encode: $wav → $dest (level=$level)"
    [[ -s "$err" ]] && { log_err "  mac stderr:"; sed 's/^/  | /' "$err" >&2; }
    return 1
  fi
}
