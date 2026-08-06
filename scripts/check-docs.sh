#!/usr/bin/env bash
# Validate repository-local links in Markdown files.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail=0

while IFS= read -r file; do
  dir=$(dirname "$file")
  while IFS= read -r target; do
    target=${target#']('}
    target=${target%')'}
    target=${target#'<'}
    target=${target%'>'}
    target=${target%%[[:space:]]\"*}
    target=${target%%#*}
    target=${target//%20/ }
    [[ -n "$target" ]] || continue
    case "$target" in
      http://*|https://*|mailto:*|data:*|/*) continue ;;
    esac
    if [[ ! -e "$dir/$target" ]]; then
      printf '%s: broken local link: %s\n' "${file#"$ROOT"/}" "$target" >&2
      fail=1
    fi
  done < <(
    grep -oE '\]\([^)]+\)' "$file" 2>/dev/null || true
  )
done < <(find "$ROOT" -type f -name '*.md' -not -path '*/node_modules/*' -print)

exit "$fail"
