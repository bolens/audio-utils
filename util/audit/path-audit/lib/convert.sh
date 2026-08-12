#!/usr/bin/env bash
# Audit one path: basename checks, parent-dir name (once per dir), length.

# Append portability issues for one path component to the named array.
# Usage: _pa_component_issues NAME OUT_ARRAY_NAME PREFIX
_pa_component_issues() {
  local name=$1 prefix=$3
  local -n _pa_out=$2
  local stem bytes
  local re_illegal='[<>:"|?*\\]'
  local re_ctrl=$'[\001-\037\177]'

  if [[ "$name" =~ $re_illegal ]]; then
    _pa_out+=("${prefix}illegal-chars")
  fi
  if [[ "$name" =~ $re_ctrl ]]; then
    _pa_out+=("${prefix}control-chars")
  fi
  if [[ "$name" == *. || "$name" == *' ' ]]; then
    _pa_out+=("${prefix}trailing-dot-or-space")
  fi
  if [[ "$name" == ' '* ]]; then
    _pa_out+=("${prefix}leading-space")
  fi
  stem=${name%%.*}
  case "${stem^^}" in
    CON | PRN | AUX | NUL | COM[1-9] | LPT[1-9])
      _pa_out+=("${prefix}reserved-dos-name")
      ;;
  esac
  bytes=$(printf '%s' "$name" | wc -c)
  if ((bytes > 255)); then
    _pa_out+=("${prefix}name-over-255-bytes")
  fi
  if command -v iconv >/dev/null 2>&1; then
    if ! printf '%s' "$name" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
      _pa_out+=("${prefix}non-utf8")
    fi
  fi
}

_pa_collision_issues() {
  local parent=$1 name=$2
  local folded normalized key stored lock record
  folded=${name,,}
  normalized=$name
  if command -v uconv >/dev/null 2>&1; then
    normalized=$(printf '%s' "$name" | uconv -x any-nfc 2>/dev/null || printf '%s' "$name")
  fi
  for key in "case:$folded" "nfc:$normalized"; do
    record="${AU_PATHAUDIT_STATE:?}/collision-$(au_sha256_str "$parent/$key")"
    lock="${record}.lock"
    (
      flock 9
      if [[ -f "$record" ]]; then
        stored=$(<"$record")
        if [[ "$stored" != "$name" ]]; then
          [[ "$key" == case:* ]] && printf 'casefold-collision\n' \
            || printf 'unicode-normalization-collision\n'
        fi
      else
        printf '%s' "$name" >"$record"
      fi
    ) 9>"$lock"
  done
}

convert_one() {
  local src="$1" base dir dbase key abs bytes parent current
  local -a issues=() collision_issues=()

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would path-audit: $src"; return 0
  fi

  base=$(basename -- "$src")
  _pa_component_issues "$base" issues ""

  dir=$(cd -- "$(dirname -- "$src")" && pwd) || {
    log_fail "$src" "cannot resolve directory"
    return 1
  }
  mapfile -t collision_issues < <(_pa_collision_issues "$dir" "$base")
  issues+=("${collision_issues[@]+"${collision_issues[@]}"}")

  # Audit every ancestor component once, not just the immediate parent.
  current=$dir
  while [[ "$current" != / ]]; do
    parent=$(dirname -- "$current")
    dbase=$(basename -- "$current")
    key=$(au_sha256_str "component:$current")
    if mkdir -- "${AU_PATHAUDIT_STATE:?}/${key}" 2>/dev/null; then
      _pa_component_issues "$dbase" issues "dir-"
      mapfile -t collision_issues < <(_pa_collision_issues "$parent" "$dbase")
      issues+=("${collision_issues[@]+"${collision_issues[@]}"}")
    fi
    current=$parent
  done

  if [[ "${PATH_AUDIT_MAX_PATH:-0}" -gt 0 ]]; then
    abs="${dir}/${base}"
    bytes=$(printf '%s' "$abs" | wc -c)
    if ((bytes > PATH_AUDIT_MAX_PATH)); then
      issues+=("path-over-${PATH_AUDIT_MAX_PATH}-bytes:${bytes}")
    fi
  fi

  if ((${#issues[@]} > 0)); then
    local IFS=';'
    log_fail "$src" "path portability issues" "${issues[*]}"
    return 1
  fi

  log_progress "ok: $src"
  log_success "$src" "clean" "" "" "ok"
}
