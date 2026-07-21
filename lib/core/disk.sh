#!/usr/bin/env bash
# Disk free-space preflight.

bytes_avail() {
  au_bytes_avail "$1"
}

# check_disk_space DIR FILE [FILE...]
# Requires CHECK_DISK_FACTOR × largest FILE free (default 3).
# Factor may be fractional (e.g. 1.5, 2).
check_disk_space() {
  local dir="$1"
  shift
  local largest=0 sz need free human_need human_free
  local factor="${CHECK_DISK_FACTOR:-3}"

  ((${#} == 0)) && return 0

  for f in "$@"; do
    sz=$(file_bytes "$f")
    if ((sz > largest)); then
      largest=$sz
    fi
  done

  need=$(awk -v l="$largest" -v f="$factor" 'BEGIN { printf "%d", (l * f) + 0.999 }')
  free=$(bytes_avail "$dir")
  if [[ -z "$free" || ! "$free" =~ ^[0-9]+$ ]]; then
    log_info "warning: could not determine free space for $dir; continuing"
    return 0
  fi

  if ((free < need)); then
    human_need=$(numfmt --to=iec --suffix=B "$need" 2>/dev/null || echo "${need}B")
    human_free=$(numfmt --to=iec --suffix=B "$free" 2>/dev/null || echo "${free}B")
    printf 'Error: insufficient free space on %s (need ~%s for temps, have %s)\n' \
      "$dir" "$human_need" "$human_free" >&2
    return 1
  fi

  log_verbose "disk ok: $dir free=$(numfmt --to=iec --suffix=B "$free" 2>/dev/null || echo "$free") need~=$(numfmt --to=iec --suffix=B "$need" 2>/dev/null || echo "$need") (×${factor})"
}
