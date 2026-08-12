#!/usr/bin/env bash
# Synchronize generated command-reference blocks in every tool README.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync-tool-readmes.sh [--check]

Refresh each conversion/ and util/ tool README from the tool's live --help.
With --check, report stale files without modifying them.
EOF
}

mode='write'
case "${1:-}" in
  '') ;;
  --check) mode=check ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }

repo=${AU_README_SYNC_ROOT:-}
if [[ -z "$repo" ]]; then
  repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fi
[[ -d "$repo/conversion" && -d "$repo/util" ]] || {
  printf 'not an audio-utils tree: %s\n' "$repo" >&2
  exit 2
}
start='<!-- BEGIN GENERATED COMMAND REFERENCE -->'
end='<!-- END GENERATED COMMAND REFERENCE -->'
stale=0

while IFS= read -r -d '' readme; do
  dir=${readme%/README.md}
  name=${dir##*/}
  entry="$dir/$name.sh"
  [[ -x "$entry" ]] || continue

  start_count=$(grep -Fxc "$start" "$readme" || true)
  end_count=$(grep -Fxc "$end" "$readme" || true)
  if [[ "$start_count" != "$end_count" || "$start_count" -gt 1 ]]; then
    printf 'malformed generated markers; refusing to modify: %s\n' \
      "${readme#"$repo"/}" >&2
    stale=1
    continue
  fi

  help=$($entry --help 2>&1) || {
    printf 'cannot read help: %s\n' "${entry#"$repo"/}" >&2
    exit 1
  }
  generated=$(mktemp)
  updated=$(mktemp "$dir/.README.md.sync.XXXXXX")
  {
    printf '%s\n' "$start"
    printf '%s\n\n' '## Command reference'
    printf '%s\n' "This block is generated from the current \`--help\` output. Run"
    printf '%s\n\n' "\`scripts/sync-tool-readmes.sh\` after changing CLI options."
    printf '%s\n' '```text'
    printf '%s\n' "$help"
    printf '%s\n' '```'
    printf '%s\n' "$end"
  } >"$generated"

  awk -v start="$start" -v end="$end" -v block="$generated" '
    $0 == start {
      while ((getline line < block) > 0) print line
      close(block)
      replacing = 1
      found = 1
      next
    }
    replacing && $0 == end { replacing = 0; next }
    !replacing { print }
    END {
      if (!found) {
        print ""
        while ((getline line < block) > 0) print line
        close(block)
      }
    }
  ' "$readme" >"$updated"

  if ! cmp -s "$readme" "$updated"; then
    if [[ "$mode" == check ]]; then
      printf 'stale: %s\n' "${readme#"$repo"/}" >&2
      stale=1
    else
      mv -- "$updated" "$readme"
      printf 'updated: %s\n' "${readme#"$repo"/}"
    fi
  fi
  rm -f -- "$generated" "$updated"
done < <(find "$repo/conversion" "$repo/util" -name README.md -print0 | sort -z)

exit "$stale"
