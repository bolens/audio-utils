#!/usr/bin/env bash
# Load optional XDG config without overriding existing environment.
#
# File: ${XDG_CONFIG_HOME:-$HOME/.config}/audio-utils/config
# Format: KEY=value (shell-style). Comments (#) and blank lines allowed.
# Only AUDIO_UTILS_* and WAV2FLAC_ROOTS keys are accepted.

audio_utils_xdg_config_home() {
  if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    printf '%s\n' "$XDG_CONFIG_HOME"
  elif [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.config"
  else
    printf '%s\n' "${TMPDIR:-/tmp}"
  fi
}

# Preferred config path (does not create).
audio_utils_config_path() {
  printf '%s\n' "$(audio_utils_xdg_config_home)/audio-utils/config"
}

# Strip matching single/double quotes from a value.
_audio_utils_unquote() {
  local v=$1
  if [[ "$v" =~ ^\"(.*)\"$ ]]; then
    v="${BASH_REMATCH[1]}"
  elif [[ "$v" =~ ^\'(.*)\'$ ]]; then
    v="${BASH_REMATCH[1]}"
  fi
  printf '%s\n' "$v"
}

# Expand safe tokens in config values: $HOME/${HOME}, $USER/${USER}, and ~/…
_audio_utils_expand_value() {
  local v=$1
  v=${v//\$\{HOME\}/${HOME-}}
  v=${v//\$HOME/${HOME-}}
  v=${v//\$\{USER\}/${USER-}}
  v=${v//\$USER/${USER-}}
  # Expand leading ~ (literal; not bash tilde expansion in [[ ]])
  # shellcheck disable=SC2088
  case "$v" in
    "~") v="${HOME-}" ;;
    "~/"*) v="${HOME-}/${v#~/}" ;;
  esac
  # Also expand ~/ after spaces (multi-root lines)
  v=${v// \~\// ${HOME-}/}
  printf '%s\n' "$v"
}

# Load config file. Existing env vars win. Returns 0 even if file missing.
audio_utils_load_config() {
  local conf line key val
  conf=$(audio_utils_config_path)
  [[ -f "$conf" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim and strip comments
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^(AUDIO_UTILS_[A-Z0-9_]+|WAV2FLAC_ROOTS)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val=$(_audio_utils_expand_value "$(_audio_utils_unquote "${BASH_REMATCH[2]}")")
      # Do not override variables already set in the environment.
      if [[ ! -v "$key" ]]; then
        printf -v "$key" '%s' "$val"
        # shellcheck disable=SC2163 # dynamic export by name in $key
        export "$key"
      fi
    else
      log_err "warning: ignoring invalid config line in $conf: $line"
    fi
  done <"$conf"
}
