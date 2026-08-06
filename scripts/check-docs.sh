#!/usr/bin/env bash
# Validate repository-local Markdown paths, reference links, and heading anchors.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail=0

anchor_exists() {
  local file=$1 wanted=$2 heading slug
  wanted=${wanted,,}
  grep -qF "id=\"$wanted\"" "$file" && return 0
  grep -qF "id='$wanted'" "$file" && return 0
  grep -qF "name=\"$wanted\"" "$file" && return 0
  grep -qF "name='$wanted'" "$file" && return 0
  while IFS= read -r heading; do
    heading=${heading##\# }
    heading=${heading#"${heading%%[!#]*}"}
    heading=${heading#"${heading%%[![:space:]]*}"}
    slug=$(printf '%s' "$heading" |
      tr '[:upper:]' '[:lower:]' |
      sed -E 's/<[^>]+>//g; s/`//g; s/[*_~]//g; s/[^[:alnum:] _-]//g; s/[[:space:]]+/-/g')
    [[ "$slug" == "$wanted" ]] && return 0
  done < <(grep -E '^#{1,6}[[:space:]]+' "$file" || true)
  return 1
}

check_target() {
  local source=$1 raw=$2 dir target path fragment=""
  dir=$(dirname "$source")
  target=$raw
  target=${target#']('}
  target=${target%')'}
  target=${target#'<'}
  target=${target%'>'}
  target=${target%%[[:space:]]\"*}
  target=${target//%20/ }
  [[ -n "$target" ]] || return 0
  case "$target" in
    http://*|https://*|mailto:*|data:*) return 0 ;;
  esac
  if [[ "$target" == *'#'* ]]; then
    fragment=${target#*#}
    target=${target%%#*}
  fi
  if [[ -z "$target" ]]; then
    path=$source
  elif [[ "$target" == /* ]]; then
    return 0
  else
    path="$dir/$target"
  fi
  if [[ ! -e "$path" ]]; then
    printf '%s: broken local link: %s\n' "${source#"$ROOT"/}" "$raw" >&2
    fail=1
    return
  fi
  if [[ -n "$fragment" && "$path" == *.md ]] && ! anchor_exists "$path" "$fragment"; then
    printf '%s: broken Markdown anchor: %s\n' "${source#"$ROOT"/}" "$raw" >&2
    fail=1
  fi
}

while IFS= read -r file; do
  while IFS= read -r target; do
    check_target "$file" "$target"
  done < <(
    {
      grep -oE '\]\([^)]+\)' "$file" 2>/dev/null || true
      sed -nE 's/^\[[^]]+\]:[[:space:]]*<?([^ >]+)>?.*/\1/p' "$file"
    } | sort -u
  )
done < <(find "$ROOT" -type f -name '*.md' -not -path '*/node_modules/*' -print)

exit "$fail"
