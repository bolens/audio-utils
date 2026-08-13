#!/usr/bin/env bash
# Require immutable full-SHA pins for third-party GitHub Actions.
set -euo pipefail

ROOT=${AUDIO_UTILS_ACTION_PINS_ROOT:-}
if [[ -z "$ROOT" ]]; then
  ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fi
[[ -d "$ROOT/.github" ]] || {
  printf 'action pin root has no .github directory: %s\n' "$ROOT" >&2
  exit 2
}
fail=0

while IFS= read -r -d '' file; do
  while IFS= read -r entry; do
    ref=${entry#*uses:}
    ref=${ref#"${ref%%[![:space:]]*}"}
    ref=${ref%%[[:space:]]#*}
    ref=${ref%\"}
    ref=${ref#\"}
    ref=${ref%\'}
    ref=${ref#\'}
    case "$ref" in
      ./*|docker://*) continue ;;
    esac
    if [[ ! "$ref" =~ ^[^@[:space:]]+@[0-9a-f]{40}$ ]]; then
      printf '%s: external action is not pinned to a full commit SHA: %s\n' \
        "${file#"$ROOT"/}" "$ref" >&2
      fail=1
    fi
  done < <(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+' "$file" || true)
done < <(
  find "$ROOT/.github" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 |
    sort -z
)

exit "$fail"
