#!/usr/bin/env bash
# Dispatch only installed audio-utils tools; forward arguments without evaluation.
set -euo pipefail
root=/opt/audio-utils
case "${1:---help}" in
  -h|--help)
    printf 'Usage: docker run IMAGE TOOL [ARGS...]\n\nTools:\n'
    find "$root/conversion" "$root/util" -name Makefile -printf '%h\n' | sed 's|.*/||' | sort
    exit 0
    ;;
  --version) cat "$root/VERSION"; exit 0 ;;
esac
tool=$1
shift
if [[ ! "$tool" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  printf 'audio-utils: invalid tool name: %s\n' "$tool" >&2
  exit 2
fi
shopt -s nullglob
matches=()
for path in "$root/conversion/$tool/$tool.sh" "$root"/util/*/"$tool/$tool.sh"; do
  [[ -f "$path" ]] && matches+=("$path")
done
if ((${#matches[@]} != 1)); then
  printf 'audio-utils: unknown or ambiguous tool: %s\n' "$tool" >&2
  exit 2
fi
exec bash "${matches[0]}" "$@"
